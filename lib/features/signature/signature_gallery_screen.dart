import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';

/// Gallery of saved signatures — pick one to apply to a document
class SignatureGalleryScreen extends StatefulWidget {
  final String? documentImagePath; // if provided, user came to apply a sig

  const SignatureGalleryScreen({super.key, this.documentImagePath});

  @override
  State<SignatureGalleryScreen> createState() => _SignatureGalleryScreenState();
}

class _SignatureGalleryScreenState extends State<SignatureGalleryScreen> {
  List<FileSystemEntity> _signatures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    final appDir = await getApplicationDocumentsDirectory();
    final sigDir = Directory(p.join(appDir.path, 'DocScanner', 'signatures'));

    if (await sigDir.exists()) {
      final files = sigDir
          .listSync()
          .where((f) => f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // newest first

      setState(() {
        _signatures = files;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSignature(FileSystemEntity file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        title: const Text('Hapus Tanda Tangan?'),
        content: const Text('Tanda tangan ini akan dihapus permanen.'),
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
      await file.delete();
      _loadSignatures();
    }
  }

  Future<void> _onSignatureTap(String signaturePath) async {
    if (widget.documentImagePath != null) {
      // Navigate to overlay screen and wait for result
      final result = await Navigator.pushNamed(
        context,
        AppRoutes.signatureOverlay,
        arguments: {
          'documentImagePath': widget.documentImagePath,
          'signaturePath': signaturePath,
        },
      );

      // If overlay returned a signed image path, pop back to editor with it
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDocument = widget.documentImagePath != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Buat baru',
            onPressed: () async {
              final result =
                  await Navigator.pushNamed(context, AppRoutes.signature);
              if (result != null) {
                _loadSignatures(); // refresh
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            )
          : _signatures.isEmpty
              ? _buildEmptyState(theme)
              : _buildGrid(theme, hasDocument),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent1.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.draw_rounded,
                size: 56, color: AppColors.accent2),
          ),
          const SizedBox(height: 20),
          Text('Belum ada tanda tangan',
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Buat tanda tangan pertamamu',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result =
                  await Navigator.pushNamed(context, AppRoutes.signature);
              if (result != null) _loadSignatures();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat Tanda Tangan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(ThemeData theme, bool hasDocument) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDocument)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih tanda tangan untuk diterapkan ke dokumen',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _signatures.length,
            itemBuilder: (context, index) {
              final file = _signatures[index];
              final fileName = p.basename(file.path);
              final dateStr = _extractDate(fileName);

              return GestureDetector(
                onTap: hasDocument
                    ? () => _onSignatureTap(file.path)
                    : null,
                onLongPress: () => _deleteSignature(file),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: AppColors.dividerLight,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Signature preview
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.file(
                            File(file.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Bottom info
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(AppRadius.lg),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.draw_rounded,
                                size: 14,
                                color: AppColors.accent2),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: theme.textTheme.labelMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasDocument)
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 12, color: AppColors.secondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _extractDate(String fileName) {
    try {
      final ms = int.parse(
          fileName.replaceAll('signature_', '').replaceAll('.png', ''));
      final date = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fileName;
    }
  }
}
