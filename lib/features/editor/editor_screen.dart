import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../models/scan_document.dart';
import '../../models/scan_page.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/reorderable_image_grid.dart';
import 'package:path/path.dart' as p;

/// Editor screen — filters, rotation, batch page management
class EditorScreen extends StatefulWidget {
  final List<String> imagePaths;
  const EditorScreen({super.key, required this.imagePaths});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final ImageProcessingService _imageService = ImageProcessingService();
  final PdfService _pdfService = PdfService();
  final FileService _fileService = FileService();

  late List<String> _currentPaths;
  int _currentPageIndex = 0;
  String _selectedFilter = 'Original';
  bool _isProcessing = false;
  bool _isGridMode = false;
  bool _isSelectMode = false;
  final Set<int> _selectedIndices = {};
  final Map<int, Map<String, String>> _filterCache = {};

  final List<String> _filters = ['Original', 'B&W', 'Magic', 'Grayscale'];

  @override
  void initState() {
    super.initState();
    _currentPaths = List.from(widget.imagePaths);
    // Default to grid mode when there are multiple pages
    if (_currentPaths.length > 1) {
      _isGridMode = true;
    }
  }

  Future<void> _applyFilter(String filter) async {
    if (filter == _selectedFilter) return;

    setState(() {
      _selectedFilter = filter;
      _isProcessing = true;
    });

    try {
      String resultPath;

      // Check cache first
      final pageCache = _filterCache[_currentPageIndex] ?? {};
      if (pageCache.containsKey(filter)) {
        resultPath = pageCache[filter]!;
      } else {
        final originalPath = widget.imagePaths[_currentPageIndex];

        switch (filter) {
          case 'B&W':
            resultPath = await _imageService.applyBlackAndWhite(originalPath);
            break;
          case 'Magic':
            resultPath = await _imageService.applyMagicColor(originalPath);
            break;
          case 'Grayscale':
            resultPath = await _imageService.applyGrayscale(originalPath);
            break;
          default:
            resultPath = originalPath;
        }

        pageCache[filter] = resultPath;
        _filterCache[_currentPageIndex] = pageCache;
      }

      setState(() {
        _currentPaths[_currentPageIndex] = resultPath;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Filter error: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rotateCurrentPage() async {
    setState(() => _isProcessing = true);
    try {
      final rotated = await _imageService.rotateClockwise(
        _currentPaths[_currentPageIndex],
      );
      setState(() {
        _currentPaths[_currentPageIndex] = rotated;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _deleteCurrentPage() {
    if (_currentPaths.length <= 1) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentPaths.removeAt(_currentPageIndex);
      if (_currentPageIndex >= _currentPaths.length) {
        _currentPageIndex = _currentPaths.length - 1;
      }
    });
  }

  Future<void> _saveDocument({List<String>? pathsToSave}) async {
    final paths = pathsToSave ?? _currentPaths;
    setState(() => _isProcessing = true);

    try {
      final documents = await _fileService.loadDocuments();

      if (!mounted) return;
      
      // Dialog to choose group
      final selectedDocId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Simpan ke Dokumen Mana?'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_rounded, color: AppColors.primary),
                    title: const Text('➕ Buat Grup Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.pop(context, 'NEW'),
                  ),
                  const Divider(),
                  ...documents.map((doc) => ListTile(
                    leading: const Icon(Icons.folder_rounded, color: AppColors.secondary),
                    title: Text(doc.name),
                    subtitle: Text('${doc.pages.length} halaman'),
                    onTap: () => Navigator.pop(context, doc.id),
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Batal'),
              ),
            ],
          );
        },
      );

      // User cancelled
      if (selectedDocId == null) {
        setState(() => _isProcessing = false);
        return;
      }

      String docId;
      String folderPath;
      String docName;
      int startIndex = 0;
      ScanDocument? existingDoc;

      if (selectedDocId == 'NEW') {
        docId = const Uuid().v4();
        folderPath = await _fileService.createDocumentFolder(docId);
        
        // Ask for new name
        final nameController = TextEditingController(text: 'Scan ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');
        if (!mounted) return;
        final customName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nama Dokumen Baru'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Masukkan nama'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
        docName = (customName != null && customName.isNotEmpty) ? customName : nameController.text.trim();
      } else {
        existingDoc = documents.firstWhere((d) => d.id == selectedDocId);
        docId = existingDoc.id;
        folderPath = existingDoc.folderPath;
        docName = existingDoc.name;
        startIndex = existingDoc.pages.length;
      }

      final publicPhotoDir = Directory('/storage/emulated/0/Download/DocScanner/Foto');
      if (!await publicPhotoDir.exists()) await publicPhotoDir.create(recursive: true);

      // Save each page
      final pages = <ScanPage>[];
      for (int i = 0; i < paths.length; i++) {
        final pageId = const Uuid().v4();
        final savedPath = await _fileService.saveImageToDocument(
          docId,
          paths[i],
          pageId,
        );
        
        pages.add(ScanPage(
          id: pageId,
          imagePath: savedPath,
          filterApplied: _selectedFilter.toLowerCase(),
          orderIndex: startIndex + i,
        ));
      }

      if (existingDoc != null) {
        existingDoc.pages.addAll(pages);
        existingDoc.updatedAt = DateTime.now();
      } else {
        // Create document
        final doc = ScanDocument(
          id: docId,
          name: docName,
          folderPath: folderPath,
          pages: pages,
        );
        documents.insert(0, doc);
      }

      // Save to persistence
      await _fileService.saveDocuments(documents);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dokumen berhasil disimpan!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    } catch (e) {
      debugPrint('Save error: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _generatePdf({List<String>? pathsToSave}) async {
    final paths = pathsToSave ?? _currentPaths;
    // Ask for PDF name first
    final defaultName = 'Scan_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}';
    final nameController = TextEditingController(text: defaultName);

    final pdfName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Nama PDF'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan nama PDF',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Buat PDF'),
          ),
        ],
      ),
    );

    if (pdfName == null || pdfName.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await _pdfService.generatePdf(
        imagePaths: paths,
        documentName: pdfName,
        outputDir: '/storage/emulated/0/Download/DocScanner/PDF',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF "$pdfName" berhasil disimpan!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('PDF error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Get the paths to save based on current context
  List<String> _getPathsToSave() {
    if (_isSelectMode && _selectedIndices.isNotEmpty) {
      final sorted = _selectedIndices.toList()..sort();
      return sorted.map((i) => _currentPaths[i]).toList();
    } else if (!_isGridMode) {
      return [_currentPaths[_currentPageIndex]];
    } else {
      return List.from(_currentPaths);
    }
  }

  String _getSaveLabel() {
    if (_isSelectMode && _selectedIndices.isNotEmpty) {
      return '${_selectedIndices.length} foto dipilih';
    } else if (!_isGridMode) {
      return 'Foto saat ini';
    } else {
      return 'Semua ${_currentPaths.length} foto';
    }
  }

  void _showSaveOptions() {
    final pathsToSave = _getPathsToSave();
    final label = _getSaveLabel();
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Simpan Sebagai',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.folder_rounded, color: AppColors.secondary),
                title: const Text('Simpan ke Grup', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Simpan ke grup dokumen baru atau yang ada',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveDocument(pathsToSave: pathsToSave);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                title: const Text('Simpan sebagai PDF', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Muncul di tab Hasil PDF',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _generatePdf(pathsToSave: pathsToSave);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_rounded, color: AppColors.accent2),
                title: const Text('Simpan sebagai Gambar', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Muncul di tab Hasil Gambar',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveAsImages(pathsToSave: pathsToSave);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsImages({List<String>? pathsToSave}) async {
    final paths = pathsToSave ?? _currentPaths;
    setState(() => _isProcessing = true);

    try {
      final photoDir = Directory('/storage/emulated/0/Download/DocScanner/Foto');
      if (!await photoDir.exists()) await photoDir.create(recursive: true);

      for (int i = 0; i < paths.length; i++) {
        final ext = p.extension(paths[i]).isNotEmpty ? p.extension(paths[i]) : '.jpg';
        final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}_$i$ext';
        await File(paths[i]).copy(p.join(photoDir.path, fileName));
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${paths.length} gambar berhasil disimpan!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    } catch (e) {
      debugPrint('Save images error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan gambar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onGridReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _currentPaths.removeAt(oldIndex);
      _currentPaths.insert(newIndex, item);
    });
  }

  void _onGridTap(int index) {
    if (_isSelectMode) {
      _toggleSelect(index);
    } else {
      setState(() {
        _currentPageIndex = index;
        _isGridMode = false;
        _selectedFilter = 'Original';
      });
    }
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _currentPaths.length) {
        _selectedIndices.clear();
        _isSelectMode = false;
      } else {
        _selectedIndices.clear();
        _selectedIndices.addAll(List.generate(_currentPaths.length, (i) => i));
      }
    });
  }

  void _enterSelectMode(int index) {
    setState(() {
      _isSelectMode = true;
      _selectedIndices.clear();
      _selectedIndices.add(index);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: (_isGridMode && !_isSelectMode) || _currentPaths.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isSelectMode) {
            _exitSelectMode();
          } else if (!_isGridMode && _currentPaths.length > 1) {
            setState(() => _isGridMode = true);
          }
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _isSelectMode ? AppColors.accent2.withValues(alpha: 0.3) : AppColors.surfaceDark,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(_isSelectMode ? Icons.close : Icons.arrow_back),
          onPressed: () {
            if (_isSelectMode) {
              _exitSelectMode();
            } else if (!_isGridMode && _currentPaths.length > 1) {
              setState(() => _isGridMode = true);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isSelectMode
              ? '${_selectedIndices.length} dipilih'
              : _isGridMode
                  ? 'Atur Urutan • ${_currentPaths.length} hal'
                  : 'Edit • ${_currentPageIndex + 1}/${_currentPaths.length}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSelectMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIndices.length == _currentPaths.length ? 'Batal Semua' : 'Pilih Semua',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ] else if (_isGridMode) ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => _enterSelectMode(0),
              tooltip: 'Pilih',
            ),
          ] else if (_currentPaths.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteCurrentPage,
              tooltip: 'Hapus halaman ini',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ─── IMAGE PREVIEW (Grid or Single) ────────────────────
          Expanded(
            child: _isGridMode
                ? ReorderableImageGrid(
                    imagePaths: _currentPaths,
                    selectedIndex: _currentPageIndex,
                    onTap: _onGridTap,
                    onReorder: _onGridReorder,
                    isSelectMode: _isSelectMode,
                    selectedIndices: _selectedIndices,
                    onSelect: _toggleSelect,
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        itemCount: _currentPaths.length,
                        controller: PageController(initialPage: _currentPageIndex),
                        onPageChanged: (index) {
                          setState(() {
                            _currentPageIndex = index;
                            _selectedFilter = 'Original';
                          });
                        },
                        itemBuilder: (context, index) {
                          return InteractiveViewer(
                            maxScale: 4.0,
                            child: Center(
                              child: Image.file(
                                File(_currentPaths[index]),
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),

                      if (_isProcessing)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.secondary),
                        ),

                      // Page indicators
                      if (_currentPaths.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_currentPaths.length, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _currentPageIndex ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _currentPageIndex
                                      ? AppColors.secondary
                                      : Colors.white30,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
          ),

          // ─── TOOLS BAR ────────────────────────
          if (!_isGridMode)
            Container(
              color: AppColors.surfaceDark,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToolButton(
                    icon: Icons.rotate_right_rounded,
                    label: 'Rotate',
                    onTap: _rotateCurrentPage,
                  ),
                  _ToolButton(
                    icon: Icons.crop_rounded,
                    label: 'Crop',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.crop,
                        arguments: _currentPaths[_currentPageIndex],
                      );
                    },
                  ),
                  _ToolButton(
                    icon: Icons.draw_rounded,
                    label: 'Tanda Tangan',
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.signatureGallery,
                        arguments: _currentPaths[_currentPageIndex],
                      );
                      if (result != null && result is String) {
                        setState(() {
                          _currentPaths[_currentPageIndex] = result;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

          // ─── FILTER BAR (only in single view) ───────────────────────
          if (!_isGridMode)
            Container(
              color: AppColors.surfaceDark,
              child: FilterChipBar(
                filters: _filters,
                selectedFilter: _selectedFilter,
                onFilterSelected: _applyFilter,
              ),
            ),

          // ─── BOTTOM ACTIONS ───────────────────
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: AppColors.surfaceDark,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _showSaveOptions,
                icon: const Icon(Icons.save_rounded, size: 20),
                label: const Text('Simpan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
