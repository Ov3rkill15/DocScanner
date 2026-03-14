import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_theme.dart';
import '../../models/scan_document.dart';

/// Document card widget for home screen grid/list view
class DocCard extends StatelessWidget {
  final ScanDocument document;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final bool isListMode;
  final bool isSelectMode;
  final bool isSelected;
  final ValueChanged<ScanDocument>? onSelect;

  const DocCard({
    super.key,
    required this.document,
    this.onTap,
    this.onDelete,
    this.onRename,
    this.isListMode = false,
    this.isSelectMode = false,
    this.isSelected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return isListMode ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (isSelectMode) {
          onSelect?.call(document);
        } else {
          onTap?.call();
        }
      },
      onLongPress: () {
        if (!isSelectMode) {
          _showContextMenu(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          border: isSelected
              ? Border.all(color: AppColors.accent2, width: 2)
              : null,
          borderRadius: AppRadius.cardRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(),
                    if (isSelected)
                      Container(color: AppColors.accent2.withValues(alpha: 0.15)),
                    if (isSelectMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => onSelect?.call(document),
                          behavior: HitTestBehavior.opaque,
                          child: _buildCheckbox(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.description_rounded,
                          size: 14, color: theme.textTheme.bodyMedium?.color),
                      const SizedBox(width: 4),
                      Text(
                        '${document.pageCount} hal',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM').format(document.updatedAt),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accent2 : Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.accent2 : Colors.white54,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildListCard(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (isSelectMode) {
          onSelect?.call(document);
        } else {
          onTap?.call();
        }
      },
      onLongPress: () {
        if (!isSelectMode) {
          _showContextMenu(context);
        }
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          border: isSelected
              ? Border.all(color: AppColors.accent2, width: 2)
              : null,
          borderRadius: AppRadius.cardRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20)),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(),
                    if (isSelected)
                      Container(color: AppColors.accent2.withValues(alpha: 0.15)),
                  ],
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      document.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${document.pageCount} halaman • ${DateFormat('dd MMM yyyy').format(document.updatedAt)}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),

            // More menu or Checkbox
            if (isSelectMode)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => onSelect?.call(document),
                  behavior: HitTestBehavior.opaque,
                  child: _buildCheckbox(),
                ),
              )
            else
              IconButton(
                onPressed: () => _showContextMenu(context),
                icon: const Icon(Icons.more_vert_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbPath = document.displayThumbnail;
    if (thumbPath != null && File(thumbPath).existsSync()) {
      return Image.file(
        File(thumbPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Placeholder
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.description_rounded,
          size: 40,
          color: AppColors.primary,
        ),
      ),
    );
  }

  void _shareDocument() {
    // Collect all image file paths from document pages
    final files = <XFile>[];
    for (final page in document.pages) {
      final path = page.displayPath;
      if (File(path).existsSync()) {
        files.add(XFile(path));
      }
    }

    if (files.isNotEmpty) {
      SharePlus.instance.share(
        ShareParams(
          files: files,
          subject: document.name,
          text: 'Dokumen: ${document.name}',
        ),
      );
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent2),
              title: const Text('Pilih'),
              onTap: () {
                Navigator.pop(ctx);
                onSelect?.call(document);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                onRename?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.info),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                _shareDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: Text('Hapus', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
