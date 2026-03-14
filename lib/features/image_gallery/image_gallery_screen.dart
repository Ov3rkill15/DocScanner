import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../../config/app_theme.dart';
import '../../services/file_service.dart';

/// Screen that displays all saved images from Download/DocScanner/Foto
class ImageGalleryScreen extends StatefulWidget {
  final bool isGridView;
  final Function(bool isSelectMode, int count, VoidCallback onSelectAll, VoidCallback onDelete, VoidCallback onShare, VoidCallback onCancel)? onSelectionChange;

  const ImageGalleryScreen({
    super.key,
    this.isGridView = true,
    this.onSelectionChange,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  final FileService _fileService = FileService();
  List<File> _imageFiles = [];
  bool _isLoading = true;

  bool _isSelectMode = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    final files = await _fileService.listSavedImages();
    setState(() {
      _imageFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _deleteImage(File file, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Hapus Gambar?'),
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
      await _fileService.deletePdf(file.path); // reuse delete method
      _loadImages();
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

  void _shareSelected() {
    if (_selectedPaths.isEmpty) return;
    final files = _selectedPaths.map((path) => XFile(path)).toList();
    SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'Berbagi ${_selectedPaths.length} Gambar',
        text: 'Membagikan gambar dari DocScanner',
      ),
    );
    _cancelSelection();
  }

  void _selectAll() {
    setState(() {
      if (_selectedPaths.length == _imageFiles.length) {
        _selectedPaths.clear();
        _isSelectMode = false;
      } else {
        _selectedPaths.clear();
        _selectedPaths.addAll(_imageFiles.map((f) => f.path));
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

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Hapus Gambar?'),
        content: Text('Apakah kamu yakin ingin menghapus ${_selectedPaths.length} gambar terpilih?'),
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
      _loadImages();
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

  Future<void> _shareImage(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal share: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openImage(File file) async {
    try {
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _renameImage(File file, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama baru'),
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
      final ext = p.extension(file.path);
      final newPath = p.join(dir, '$newName$ext');
      try {
        await file.rename(newPath);
        _loadImages();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal rename: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showImageOptions(File file) {
    final name = p.basenameWithoutExtension(file.path);
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
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent2),
                title: const Text('Pilih', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _toggleSelection(file.path); },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: AppColors.primaryLight),
                title: const Text('Buka', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _openImage(file); },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.accent1),
                title: const Text('Rename', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _renameImage(file, name); },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppColors.secondary),
                title: const Text('Bagikan', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _shareImage(file); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Hapus', style: TextStyle(color: AppColors.error)),
                onTap: () { Navigator.pop(ctx); _deleteImage(file, name); },
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_imageFiles.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadImages,
      color: AppColors.primary,
      child: widget.isGridView
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _imageFiles.length,
              itemBuilder: (context, index) {
                final file = _imageFiles[index];
                return _buildImageGridCard(file);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: _imageFiles.length,
              itemBuilder: (context, index) {
                final file = _imageFiles[index];
                return _buildImageListCard(file);
              },
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
            child: const Icon(Icons.image_rounded, size: 64, color: AppColors.accent2),
          ),
          const SizedBox(height: 20),
          Text('Belum ada Gambar', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Simpan gambar dari editor', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildImageGridCard(File file) {
    final name = p.basenameWithoutExtension(file.path);
    final isSelected = _selectedPaths.contains(file.path);

    return GestureDetector(
      onTap: () {
        if (_isSelectMode) {
          _toggleSelection(file.path);
        } else {
          _openImage(file);
        }
      },
      onLongPress: () {
        if (!_isSelectMode) {
          _showImageOptions(file);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: AppColors.accent2, width: 2) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(file, fit: BoxFit.cover, cacheWidth: 300),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (isSelected)
                Container(color: AppColors.accent2.withValues(alpha: 0.15)),
              if (_isSelectMode)
                Positioned(
                  top: 6,
                  right: 6,
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

  Widget _buildImageListCard(File file) {
    final name = p.basenameWithoutExtension(file.path);
    final isSelected = _selectedPaths.contains(file.path);
    final stat = file.statSync();
    final modified = stat.modified;
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(modified);
    final sizeFormatted = _fileService.formatBytes(stat.size);

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
              _openImage(file);
            }
          },
          onLongPress: () {
            if (!_isSelectMode) {
              _showImageOptions(file);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: AppColors.accent2, width: 2) : null,
              borderRadius: AppRadius.cardRadius,
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Image Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover, cacheWidth: 150),
                        if (isSelected)
                          Container(color: AppColors.accent2.withValues(alpha: 0.15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
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
                            sizeFormatted,
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
                    onPressed: () => _showImageOptions(file),
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
