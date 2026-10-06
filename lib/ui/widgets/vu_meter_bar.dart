import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Flat Geometric VU Meter Bar.
///
/// Features clean solid rectangular geometry and clear signal color progression
/// (Green -> Yellow -> Red).
class VuMeterBar extends StatelessWidget {
  final double level; // 0.0 to 1.0
  final double peakHold; // 0.0 to 1.0
  final double height;

  const VuMeterBar({
    super.key,
    required this.level,
    this.peakHold = 0.0,
    this.height = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0.0, 1.0);
    final clampedPeak = peakHold.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.circular(1),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final activeWidth = totalWidth * clampedLevel;
          final peakPos = (totalWidth * clampedPeak).clamp(0.0, totalWidth - 2.0);

          return Stack(
            children: [
              // Geometric active level bar
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: Container(
                  width: activeWidth,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.vuGreen,
                        AppColors.vuYellow,
                        AppColors.vuRed,
                      ],
                      stops: [0.65, 0.85, 1.0],
                    ),
                  ),
                ),
              ),

              // Peak Hold indicator line
              if (clampedPeak > 0.05)
                Positioned(
                  left: peakPos,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: clampedPeak > 0.85 ? AppColors.vuRed : AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
