import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

/// Bauhaus Segmented Grid Count Selector (4 | 8).
class GridCountSelector extends StatelessWidget {
  final int selectedCount;
  final ValueChanged<int> onSelectCount;
  final List<int> counts;

  const GridCountSelector({
    super.key,
    required this.selectedCount,
    required this.onSelectCount,
    this.counts = const [4, 8],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: counts.map((count) {
          final isSelected = count == selectedCount;
          return Semantics(
            button: true,
            selected: isSelected,
            label: '$count scenes grid layout',
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  Haptics.selection();
                  onSelectCount(count);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? const Color(0xFF090A0E) : AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
