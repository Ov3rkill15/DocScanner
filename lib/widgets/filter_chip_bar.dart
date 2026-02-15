import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Horizontal filter selector bar for editor screen
class FilterChipBar extends StatelessWidget {
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final Map<String, String>? thumbnails; // filter name -> thumbnail path

  const FilterChipBar({
    super.key,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.thumbnails,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == selectedFilter;

          return GestureDetector(
            onTap: () => onFilterSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: _getFilterColor(filter),
                    ),
                    child: Icon(
                      _getFilterIcon(filter),
                      color: isSelected ? Colors.white : Colors.white70,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filter,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter.toLowerCase()) {
      case 'original':
        return AppColors.primary;
      case 'b&w':
        return Colors.grey[800]!;
      case 'magic':
        return AppColors.secondary;
      case 'grayscale':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  IconData _getFilterIcon(String filter) {
    switch (filter.toLowerCase()) {
      case 'original':
        return Icons.image_rounded;
      case 'b&w':
        return Icons.contrast_rounded;
      case 'magic':
        return Icons.auto_fix_high_rounded;
      case 'grayscale':
        return Icons.filter_b_and_w_rounded;
      default:
        return Icons.filter_rounded;
    }
  }
}
