import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Camera mode selector — Document, ID Card, QR Code tabs
class ModeSelector extends StatelessWidget {
  final String selectedMode;
  final ValueChanged<String> onModeChanged;
  final List<String> modes;

  const ModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    this.modes = const ['ID CARD', 'DOCUMENT', 'QR CODE'],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: modes.map((mode) {
          final isActive = mode == selectedMode;
          return GestureDetector(
            onTap: () => onModeChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: AppRadius.chipRadius,
                border: Border.all(
                  color: isActive ? AppColors.primary : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: isActive ? 13 : 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
