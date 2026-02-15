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
  final Map<int, Map<String, String>> _filterCache = {};

  final List<String> _filters = ['Original', 'B&W', 'Magic', 'Grayscale'];

  @override
  void initState() {
    super.initState();
    _currentPaths = List.from(widget.imagePaths);
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

  Future<void> _saveDocument() async {
    setState(() => _isProcessing = true);

    try {
      final docId = const Uuid().v4();
      final folderPath = await _fileService.createDocumentFolder(docId);

      // Save each page
      final pages = <ScanPage>[];
      for (int i = 0; i < _currentPaths.length; i++) {
        final pageId = const Uuid().v4();
        final savedPath = await _fileService.saveImageToDocument(
          docId,
          _currentPaths[i],
          pageId,
        );
        pages.add(ScanPage(
          id: pageId,
          imagePath: savedPath,
          filterApplied: _selectedFilter.toLowerCase(),
          orderIndex: i,
        ));
      }

      // Create document
      final doc = ScanDocument(
        id: docId,
        name: 'Scan ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        folderPath: folderPath,
        pages: pages,
      );

      // Save to persistence
      final documents = await _fileService.loadDocuments();
      documents.insert(0, doc);
      await _fileService.saveDocuments(documents);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dokumen berhasil disimpan!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
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

  Future<void> _generatePdf() async {
    setState(() => _isProcessing = true);

    try {
      final pdfPath = await _pdfService.generatePdf(
        imagePaths: _currentPaths,
        documentName:
            'Scan_${DateTime.now().millisecondsSinceEpoch}',
        outputDir: '/storage/emulated/0/Download/DocScanner',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF tersimpan di: $pdfPath'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
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

  void _extractText() {
    Navigator.pushNamed(
      context,
      AppRoutes.ocr,
      arguments: _currentPaths[_currentPageIndex],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        title: Text(
          'Edit • ${_currentPageIndex + 1}/${_currentPaths.length}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_currentPaths.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteCurrentPage,
              tooltip: 'Hapus halaman ini',
            ),
          IconButton(
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: _extractText,
            tooltip: 'OCR',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── IMAGE PREVIEW ────────────────────
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: _currentPaths.length,
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
                      // Replace current page with the signed version
                      setState(() {
                        _currentPaths[_currentPageIndex] = result;
                      });
                    }
                  },
                ),
                _ToolButton(
                  icon: Icons.text_snippet_rounded,
                  label: 'OCR',
                  onTap: _extractText,
                ),
              ],
            ),
          ),

          // ─── FILTER BAR ───────────────────────
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
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _generatePdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _saveDocument,
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: const Text('Simpan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
