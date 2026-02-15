import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../models/scan_document.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../widgets/doc_card.dart';

/// Home screen — document grid with search and FAB to scan
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FileService _fileService = FileService();
  List<ScanDocument> _documents = [];
  List<ScanDocument> _filteredDocuments = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;
  bool _isGridView = true;
  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadDocuments();
    _checkSharedImage();
  }

  Future<void> _checkSharedImage() async {

    final sharedPath = await ImageProcessingService().getSharedImage();
    if (sharedPath != null && mounted) {

      Navigator.pushNamed(
        context,
        AppRoutes.crop,
        arguments: sharedPath,
      ).then((_) => _loadDocuments());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fabAnimController.dispose();
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

  void _navigateToCamera() {
    Navigator.pushNamed(context, AppRoutes.camera).then((_) => _loadDocuments());
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
                child: Row(
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


              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _filteredDocuments.isEmpty
                        ? _buildEmptyState()
                        : _isGridView
                            ? _buildGridView()
                            : _buildListView(),
              ),
            ],
          ),
        ),


        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final results = await ImageProcessingService().scanDocument();
            if (results.isNotEmpty && mounted) {
              Navigator.pushNamed(
                context,
                AppRoutes.editor,
                arguments: {'imagePaths': results},
              ).then((_) => _loadDocuments());
            }
          },
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
          ),
        );
      },
    );
  }
}

/// Quick action chip for horizontal scroll bar
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadius.chipRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.chipRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
