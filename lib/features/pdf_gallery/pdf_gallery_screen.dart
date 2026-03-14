import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import '../../config/app_theme.dart';
import '../../services/file_service.dart';

/// Screen that displays all saved PDFs from Download/DocScanner/PDF
/// Allows users to open, share, and delete PDFs directly from the app.
class PdfGalleryScreen extends StatefulWidget {
  final bool isGridView;
  final Function(bool isSelectMode, int count, VoidCallback onSelectAll, VoidCallback onDelete, VoidCallback onShare, VoidCallback onCancel)? onSelectionChange;

  const PdfGalleryScreen({
    super.key,
    this.isGridView = true,
    this.onSelectionChange,
  });

  @override
  State<PdfGalleryScreen> createState() => _PdfGalleryScreenState();
}

class _PdfGalleryScreenState extends State<PdfGalleryScreen> {
  final FileService _fileService = FileService();
  List<File> _pdfFiles = [];
  bool _isLoading = true;

  bool _isSelectMode = false;
  final Set<String> _selectedPaths = {};
  
  static final Map<String, Uint8List> _thumbnailCache = {};

  Future<Uint8List?> _generatePdfThumbnail(File file) async {
    if (_thumbnailCache.containsKey(file.path)) {
      return _thumbnailCache[file.path];
    }
    try {
      final bytes = await file.readAsBytes();
      await for (final page in Printing.raster(bytes, pages: [0], dpi: 72)) {
        final image = await page.toPng();
        _thumbnailCache[file.path] = image;
        return image;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    setState(() => _isLoading = true);
    final files = await _fileService.listSavedPdfs();
    setState(() {
      _pdfFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _deletePdf(File file, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Hapus PDF?'),
        content: Text('Apakah kamu yakin ingin menghapus "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _fileService.deletePdf(file.path);
      _loadPdfs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" berhasil dihapus'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    }
  }

  void _updateParentSelection() {
    if (widget.onSelectionChange != null) {
      widget.onSelectionChange!(
        _isSelectMode,
        _selectedPaths.length,
        _selectAll,
        _deleteSelected,
        _shareSelected,
        _cancelSelection,
      );
    }
  }

  void _selectAll() {
    setState(() {
      if (_selectedPaths.length == _pdfFiles.length) {
        _selectedPaths.clear();
        _isSelectMode = false;
      } else {
        _selectedPaths.clear();
        _selectedPaths.addAll(_pdfFiles.map((f) => f.path));
        _isSelectMode = true;
      }
      _updateParentSelection();
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectMode = false;
      _selectedPaths.clear();
      _updateParentSelection();
    });
  }

  void _shareSelected() {
    if (_selectedPaths.isEmpty) return;
    final files = _selectedPaths.map((path) => XFile(path)).toList();
    SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'Berbagi ${_selectedPaths.length} PDF',
        text: 'Membagikan PDF dari DocScanner',
      ),
    );
    _cancelSelection();
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Hapus PDF?'),
        content: Text('Apakah kamu yakin ingin menghapus ${_selectedPaths.length} PDF terpilih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      for (final path in _selectedPaths) {
        await _fileService.deletePdf(path);
      }
      _cancelSelection();
      _loadPdfs();
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) _isSelectMode = false;
      } else {
        _selectedPaths.add(path);
        _isSelectMode = true;
      }
      _updateParentSelection();
    });
  }

  Future<void> _renamePdf(File file, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nama baru',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final dir = p.dirname(file.path);
      final newPath = p.join(dir, '$newName.pdf');
      try {
        await file.rename(newPath);
        _loadPdfs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil di-rename ke "$newName"'),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal rename: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openPdf(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak bisa membuka PDF: ${result.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal share: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPdfOptions(File file, Map<String, dynamic> info) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // File name header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  info['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                info['sizeFormatted'] as String,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent2),
                title: const Text('Pilih', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleSelection(file.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: AppColors.primaryLight),
                title: const Text('Buka', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPdf(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.accent1),
                title: const Text('Rename', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _renamePdf(file, info['name'] as String);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppColors.secondary),
                title: const Text('Bagikan', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sharePdf(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Hapus', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deletePdf(file, info['name'] as String);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_pdfFiles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPdfs,
      color: AppColors.primary,
      child: widget.isGridView
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _pdfFiles.length,
              itemBuilder: (context, index) {
                final file = _pdfFiles[index];
                final info = _fileService.getPdfInfo(file);
                return _buildPdfGridCard(file, info);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: _pdfFiles.length,
              itemBuilder: (context, index) {
                final file = _pdfFiles[index];
                final info = _fileService.getPdfInfo(file);
                return _buildPdfListCard(file, info);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent2.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
              color: AppColors.accent2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum ada PDF',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Buat PDF dari halaman editor',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accent2 : Colors.black.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.accent2 : Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildPdfGridCard(File file, Map<String, dynamic> info) {
    final modified = info['modified'] as DateTime;
    final dateStr = DateFormat('dd MMM').format(modified);
    final isSelected = _selectedPaths.contains(file.path);

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () {
          if (_isSelectMode) {
            _toggleSelection(file.path);
          } else {
            _openPdf(file);
          }
        },
        onLongPress: () {
          if (!_isSelectMode) {
            _showPdfOptions(file, info);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: AppColors.accent2, width: 2) : null,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // PDF Thumbnail Background
              FutureBuilder<Uint8List?>(
                future: _generatePdfThumbnail(file),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: Theme.of(context).cardTheme.color,
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.error,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Info Overlay
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        info['name'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${info['sizeFormatted']} • $dateStr',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent2.withValues(alpha: 0.15),
                    borderRadius: AppRadius.cardRadius,
                  ),
                ),
              if (_isSelectMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _toggleSelection(file.path),
                    behavior: HitTestBehavior.opaque,
                    child: _buildCheckbox(isSelected),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfListCard(File file, Map<String, dynamic> info) {
    final modified = info['modified'] as DateTime;
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(modified);
    final isSelected = _selectedPaths.contains(file.path);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () {
            if (_isSelectMode) {
              _toggleSelection(file.path);
            } else {
              _openPdf(file);
            }
          },
          onLongPress: () {
            if (!_isSelectMode) {
              _showPdfOptions(file, info);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: AppColors.accent2, width: 2) : null,
              borderRadius: AppRadius.cardRadius,
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // PDF Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: FutureBuilder<Uint8List?>(
                      future: _generatePdfThumbnail(file),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.error,
                            size: 26,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info['name'] as String,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateStr,
                              style: Theme.of(context).textTheme.labelMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.sd_storage_rounded,
                            size: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            info['sizeFormatted'] as String,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action button or Checkbox
                if (_isSelectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => _toggleSelection(file.path),
                      behavior: HitTestBehavior.opaque,
                      child: _buildCheckbox(isSelected),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.6),
                    onPressed: () => _showPdfOptions(file, info),
                    tooltip: 'Opsi',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
