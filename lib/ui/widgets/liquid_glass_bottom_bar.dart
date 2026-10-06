import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

/// Flat Minimalist Console Dock Navigation Bar for ObsControl.
///
/// Features docked edge-to-edge alignment with a crisp hairline top divider,
/// precision 2.5px flat top-edge accent indicators, and clean typographic hierarchy.
class LiquidGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isLandscape;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isLandscape = false,
  });

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.view_quilt_outlined,
      activeIcon: Icons.view_quilt_rounded,
      label: 'Switcher',
      tooltip: 'Scene Switcher',
    ),
    _NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Multiview',
      tooltip: 'Multiview Monitor',
    ),
    _NavItem(
      icon: Icons.equalizer_outlined,
      activeIcon: Icons.equalizer_rounded,
      label: 'Audio',
      tooltip: 'Audio Mixer',
    ),
    _NavItem(
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
      label: 'Settings',
      tooltip: 'Connection Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final barBody = SizedBox(
      height: 54,
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isSelected = currentIndex == index;
          return Expanded(
            child: _buildItem(context, index, item, isSelected),
          );
        }),
      ),
    );

    if (isLandscape) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: barBody,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.surfaceBorder,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: barBody,
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, _NavItem item, bool isSelected) {
    return Tooltip(
      message: item.tooltip,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: item.label,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            onTap(index);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Minimalist active top indicator bar (Flat geometric accent)
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentCyan : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),

              // Tab Icon and Label
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 21,
                      color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.6,
                        color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String tooltip;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.tooltip,
  });
}
