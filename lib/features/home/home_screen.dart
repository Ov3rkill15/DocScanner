import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../models/scan_document.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../widgets/doc_card.dart';
import '../pdf_gallery/pdf_gallery_screen.dart';
import '../image_gallery/image_gallery_screen.dart';
import 'dart:async';

/// Home screen — document grid with search and FAB to scan
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final FileService _fileService = FileService();
  List<ScanDocument> _documents = [];
  List<ScanDocument> _filteredDocuments = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;
  bool _isGridView = true;
  late AnimationController _fabAnimController;
  late TabController _tabController;
  
  // Global Selection State
  bool _isSelectMode = false;
  int _selectedCount = 0;
  VoidCallback? _onSelectAll;
  VoidCallback? _onDeleteSelected;
  VoidCallback? _onCancelSelection;
  VoidCallback? _onShareSelected;

  // Selection state for Tab 0 (Dokumen)
  final Set<String> _selectedDocIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _cancelSelection();
      }
    });
    _loadDocuments();
    _initShareIntentHandling();
  }

  void _initShareIntentHandling() {
    // Check for shared media on startup
    _checkSharedImage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSharedImage();
    }
  }

  Future<void> _checkSharedImage() async {
    final sharedPaths = await ImageProcessingService().getSharedImages();
    if (sharedPaths.isNotEmpty && mounted) {
      Navigator.pushNamed(
        context,
        AppRoutes.editor,
        arguments: {'imagePaths': sharedPaths},
      ).then((_) => _loadDocuments());
    }
  }

  void _onChildSelectionChange(bool isSelectMode, int count, VoidCallback onSelectAll, VoidCallback onDelete, VoidCallback onShare, VoidCallback onCancel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isSelectMode = isSelectMode;
        _selectedCount = count;
        _onSelectAll = onSelectAll;
        _onDeleteSelected = onDelete;
        _onShareSelected = onShare;
        _onCancelSelection = onCancel;
      });
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectMode = false;
      _selectedCount = 0;
      _selectedDocIds.clear();
      _onSelectAll = null;
      _onDeleteSelected = null;
      _onShareSelected = null;
      _onCancelSelection = null;
    });
  }

  void _updateGlobalSelection() {
    _selectedCount = _selectedDocIds.length;
    _onSelectAll = () {
      setState(() {
        if (_selectedDocIds.length == _filteredDocuments.length) {
          _selectedDocIds.clear();
          _cancelSelection();
        } else {
          _selectedDocIds.clear();
          _selectedDocIds.addAll(_filteredDocuments.map((d) => d.id));
          _updateGlobalSelection();
        }
      });
    };
    _onCancelSelection = _cancelSelection;
    _onDeleteSelected = () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
          title: const Text('Hapus Dokumen?'),
          content: Text('Apakah kamu yakin ingin menghapus $_selectedCount dokumen terpilih?'),
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
        for (final id in _selectedDocIds) {
          await _fileService.deleteDocument(id);
          _documents.removeWhere((d) => d.id == id);
        }
        await _fileService.saveDocuments(_documents);
        setState(() {
          _filteredDocuments = _fileService.searchDocuments(_documents, _searchController.text);
        });
        _cancelSelection();
      }
    };
    _onShareSelected = () {
      final files = <XFile>[];
      for (final id in _selectedDocIds) {
        final doc = _documents.firstWhere((d) => d.id == id);
        for (final page in doc.pages) {
          final path = page.displayPath;
          if (File(path).existsSync()) {
            files.add(XFile(path));
          }
        }
      }
      if (files.isNotEmpty) {
        SharePlus.instance.share(
          ShareParams(
            files: files,
            subject: 'Berbagi $_selectedCount Dokumen',
            text: 'Membagikan $_selectedCount dokumen dari DocScanner',
          ),
        );
      }
      _cancelSelection();
    };
  }

  void _toggleDocSelection(ScanDocument doc) {
    setState(() {
      if (_selectedDocIds.contains(doc.id)) {
        _selectedDocIds.remove(doc.id);
        if (_selectedDocIds.isEmpty) {
          _cancelSelection();
        } else {
          _updateGlobalSelection();
        }
      } else {
        _selectedDocIds.add(doc.id);
        _isSelectMode = true;
        _updateGlobalSelection();
      }
    });
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fabAnimController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await _fileService.loadDocuments();
    setState(() {
      _documents = docs;
      _filteredDocuments = docs;
      _isLoading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _filteredDocuments = _fileService.searchDocuments(_documents, query);
    });
  }

  Future<void> _deleteDocument(ScanDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Hapus Dokumen?'),
        content: Text('Apakah kamu yakin ingin menghapus "${doc.name}"?'),
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
      await _fileService.deleteDocument(doc.id);
      _documents.removeWhere((d) => d.id == doc.id);
      await _fileService.saveDocuments(_documents);
      setState(() {
        _filteredDocuments = _fileService.searchDocuments(
            _documents, _searchController.text);
      });
    }
  }

  Future<void> _renameDocument(ScanDocument doc) async {
    final controller = TextEditingController(text: doc.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Rename Dokumen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nama dokumen baru',
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

    if (newName != null && newName.isNotEmpty) {
      await _fileService.renameDocument(_documents, doc.id, newName);
      setState(() {
        _filteredDocuments = _fileService.searchDocuments(
            _documents, _searchController.text);
      });
    }
  }

  Future<void> _handleScan() async {
    final results = await ImageProcessingService().scanDocument();
    if (!mounted) return;
    if (results.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.editor,
        arguments: {'imagePaths': results},
      ).then((_) => _loadDocuments());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      // Dismiss keyboard when tapping empty area
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _isSelectMode
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _onCancelSelection ?? _cancelSelection,
                        ),
                        Text('$_selectedCount dipilih', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: _onSelectAll,
                          child: const Text('Pilih Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: AppColors.secondary),
                          onPressed: _onShareSelected,
                          tooltip: 'Bagikan Terpilih',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: _onDeleteSelected,
                          tooltip: 'Hapus Terpilih',
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DocScanner',
                              style: theme.textTheme.displayMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_documents.length} dokumen',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => _isGridView = !_isGridView);
                          },
                          icon: Icon(
                            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
              ),


              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Cari dokumen...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                              _searchFocusNode.unfocus();
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.surfaceDark
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    color: AppColors.primary,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.brightness == Brightness.dark
                      ? Colors.white60
                      : AppColors.textSecondaryLight,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('Dokumen'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('PDF'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('Gambar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Dokumen
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          )
                        : _filteredDocuments.isEmpty
                            ? _buildEmptyState()
                            : _isGridView
                                ? _buildGridView()
                                : _buildListView(),
                    // Tab 2: Hasil PDF
                    PdfGalleryScreen(
                      isGridView: _isGridView,
                      onSelectionChange: _onChildSelectionChange,
                    ),
                    // Tab 3: Hasil Gambar
                    ImageGalleryScreen(
                      isGridView: _isGridView,
                      onSelectionChange: _onChildSelectionChange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),


        floatingActionButton: FloatingActionButton(
          onPressed: _handleScan,
          child: const Icon(Icons.document_scanner_rounded, size: 26),
        ),
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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum ada dokumen',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap tombol Scan untuk mulai memindai',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = _filteredDocuments[index];
        return DocCard(
          document: doc,
          onTap: () {
            if (doc.pages.isNotEmpty) {
              Navigator.pushNamed(context, AppRoutes.editor, arguments: {
                'imagePaths': doc.pages.map((p) => p.displayPath).toList(),
              });
            }
          },
          onDelete: () => _deleteDocument(doc),
          onRename: () => _renameDocument(doc),
          isSelectMode: _isSelectMode,
          isSelected: _selectedDocIds.contains(doc.id),
          onSelect: _toggleDocSelection,
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = _filteredDocuments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DocCard(
            document: doc,
            isListMode: true,
            onTap: () {
              if (doc.pages.isNotEmpty) {
                Navigator.pushNamed(context, AppRoutes.editor, arguments: {
                  'imagePaths': doc.pages.map((p) => p.displayPath).toList(),
                });
              }
            },
            onDelete: () => _deleteDocument(doc),
            onRename: () => _renameDocument(doc),
            isSelectMode: _isSelectMode,
            isSelected: _selectedDocIds.contains(doc.id),
            onSelect: _toggleDocSelection,
          ),
        );
      },
    );
  }
}


