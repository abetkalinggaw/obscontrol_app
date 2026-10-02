import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'grid_count_selector.dart';

/// Shared section header used by Switcher, Multiview, and
/// LandscapeMultiviewScreen above the scene grid. Provides a consistent
/// label + grid count selector row with identical padding on every surface.
class SceneMonitorHeader extends StatelessWidget {
  final String label;
  final int gridCount;
  final ValueChanged<int> onSelectCount;

  /// Extra trailing widget (e.g. a "HIDE CONTROLLER" button in landscape).
  final Widget? trailing;

  const SceneMonitorHeader({
    super.key,
    required this.label,
    required this.gridCount,
    required this.onSelectCount,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GridCountSelector(
            selectedCount: gridCount,
            onSelectCount: onSelectCount,
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
