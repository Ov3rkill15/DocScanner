import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A 2-column reorderable grid of images with drag-and-drop + selection support.
class ReorderableImageGrid extends StatefulWidget {
  final List<String> imagePaths;
  final ValueChanged<int> onTap;
  final void Function(int oldIndex, int newIndex) onReorder;
  final int? selectedIndex;
  final bool isSelectMode;
  final Set<int> selectedIndices;
  final ValueChanged<int>? onSelect;

  const ReorderableImageGrid({
    super.key,
    required this.imagePaths,
    required this.onTap,
    required this.onReorder,
    this.selectedIndex,
    this.isSelectMode = false,
    this.selectedIndices = const {},
    this.onSelect,
  });

  @override
  State<ReorderableImageGrid> createState() => _ReorderableImageGridState();
}

class _ReorderableImageGridState extends State<ReorderableImageGrid> {
  int? _dragIndex;
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: widget.imagePaths.length,
      itemBuilder: (context, index) {
        return _buildDraggableItem(index);
      },
    );
  }

  Widget _buildDraggableItem(int index) {
    final imagePath = widget.imagePaths[index];
    final isHighlighted = widget.selectedIndex == index;
    final isDragging = _dragIndex == index;
    final isHovering = _hoverIndex == index;
    final isChecked = widget.selectedIndices.contains(index);

    final tileWidget = _GridImageTile(
      imagePath: imagePath,
      pageNumber: index + 1,
      isSelected: isHighlighted || isHovering,
      isDragging: isDragging,
      isSelectMode: widget.isSelectMode,
      isChecked: isChecked,
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (details.data != index) {
          setState(() => _hoverIndex = index);
          return true;
        }
        return false;
      },
      onLeave: (_) {
        setState(() {
          if (_hoverIndex == index) _hoverIndex = null;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() => _hoverIndex = null);
        widget.onReorder(details.data, index);
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: index,
          delay: const Duration(milliseconds: 200),
          hapticFeedbackOnStart: true,
          feedback: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: (MediaQuery.of(context).size.width - 34) / 2,
              height: (MediaQuery.of(context).size.width - 34) / 2 / 0.75,
              child: _GridImageTile(
                imagePath: imagePath,
                pageNumber: index + 1,
                isSelected: true,
                isDragging: true,
                isSelectMode: false,
                isChecked: false,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: tileWidget,
          ),
          onDragStarted: () => setState(() => _dragIndex = index),
          onDragEnd: (_) => setState(() {
            _dragIndex = null;
            _hoverIndex = null;
          }),
          onDraggableCanceled: (_, _) => setState(() {
            _dragIndex = null;
            _hoverIndex = null;
          }),
          child: GestureDetector(
            onTap: () {
              if (widget.isSelectMode && widget.onSelect != null) {
                widget.onSelect!(index);
              } else {
                widget.onTap(index);
              }
            },
            child: tileWidget,
          ),
        );
      },
    );
  }
}

/// A single image tile in the grid (appearance only, no gesture handling).
class _GridImageTile extends StatelessWidget {
  final String imagePath;
  final int pageNumber;
  final bool isSelected;
  final bool isDragging;
  final bool isSelectMode;
  final bool isChecked;

  const _GridImageTile({
    required this.imagePath,
    required this.pageNumber,
    required this.isSelected,
    required this.isDragging,
    required this.isSelectMode,
    required this.isChecked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isChecked
              ? AppColors.accent2
              : isSelected
                  ? AppColors.secondary
                  : AppColors.dividerDark,
          width: isChecked ? 3 : isSelected ? 2.5 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image
            Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              cacheWidth: 300,
            ),

            // Dim overlay when checked
            if (isChecked)
              Container(
                color: AppColors.accent2.withValues(alpha: 0.15),
              ),

            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Page number badge
            Positioned(
              bottom: 6,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'Hal $pageNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Select mode: checkbox / Normal mode: drag handle
            Positioned(
              top: 6,
              right: 6,
              child: isSelectMode
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isChecked
                            ? AppColors.accent2
                            : Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isChecked ? AppColors.accent2 : Colors.white54,
                          width: 2,
                        ),
                      ),
                      child: isChecked
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    )
                  : Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
