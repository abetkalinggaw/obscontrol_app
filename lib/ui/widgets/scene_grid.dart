import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/obs_scene.dart';
import 'scene_preview_box.dart';

class SceneGrid extends StatelessWidget {
  final List<ObsScene> scenes;
  final String activeProgramScene;
  final String activePreviewScene;
  final bool studioModeEnabled;
  final bool isLocked;
  final ValueChanged<String>? onSelectScene;
  final ValueChanged<String>? onCutScene;
  final void Function(int oldIndex, int newIndex)? onReorderScene;
  final EdgeInsetsGeometry padding;
  final int? crossAxisCount;
  final double? childAspectRatio;
  final int gridCount;
  final Alignment alignment;

  const SceneGrid({
    super.key,
    required this.scenes,
    required this.activeProgramScene,
    required this.activePreviewScene,
    required this.studioModeEnabled,
    this.isLocked = false,
    this.onSelectScene,
    this.onCutScene,
    this.onReorderScene,
    this.padding = EdgeInsets.zero,
    this.crossAxisCount,
    this.childAspectRatio,
    this.gridCount = 8,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.layers_clear_outlined,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Scenes Available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Connect to OBS Studio to load your scene collections.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = padding.resolve(Directionality.of(context));
        final availableWidth = constraints.maxWidth - pad.horizontal;
        final availableHeight = constraints.maxHeight - pad.vertical;
        final isWide = availableWidth > availableHeight;

        // Determine columns and rows so content fits 100% on one page without scrolling
        int cols;
        int rows;

        if (crossAxisCount != null) {
          cols = crossAxisCount!;
          rows = (gridCount / cols).ceil();
        } else {
          switch (gridCount) {
            case 4:
              if (isWide && (availableWidth / (availableHeight > 0 ? availableHeight : 1) > 2.4)) {
                cols = 4;
                rows = 1;
              } else {
                cols = 2;
                rows = 2;
              }
              break;
            case 8:
            default:
              if (isWide) {
                cols = 4;
                rows = 2;
              } else {
                cols = 2;
                rows = 4;
              }
              break;
          }
        }

        const double crossAxisSpacing = 6.0;
        const double mainAxisSpacing = 6.0;

        final totalHorizGaps = (cols - 1) * crossAxisSpacing;
        final totalVertGaps = (rows - 1) * mainAxisSpacing;

        final targetAspectRatio = childAspectRatio ?? (16 / 9);

        // Calculate item size if constrained by width
        final widthBasedItemWidth = (availableWidth - totalHorizGaps) / cols;
        final widthBasedItemHeight = widthBasedItemWidth / targetAspectRatio;
        final widthBasedTotalHeight = rows * widthBasedItemHeight + totalVertGaps;

        // Available height with 2px rounding safety margin
        final safeAvailableHeight = availableHeight > 2 ? availableHeight - 2 : 0.0;

        double finalGridWidth;
        double finalGridHeight;

        if (safeAvailableHeight > 0 && widthBasedTotalHeight > safeAvailableHeight) {
          // Height-constrained: scale down item size to fit safeAvailableHeight
          // while preserving exact 16:9 aspect ratio
          final heightBasedItemHeight = (safeAvailableHeight - totalVertGaps) / rows;
          final heightBasedItemWidth = heightBasedItemHeight * targetAspectRatio;
          finalGridWidth = cols * heightBasedItemWidth + totalHorizGaps;
          finalGridHeight = safeAvailableHeight;
        } else {
          // Width-constrained: item width fills available width, height fits easily
          finalGridWidth = availableWidth;
          finalGridHeight = widthBasedTotalHeight;
        }

        final finalItemWidth = (finalGridWidth - totalHorizGaps) / cols;
        final finalItemHeight = finalItemWidth / targetAspectRatio;

        return Padding(
          padding: padding,
          child: Align(
            alignment: alignment,
            child: SizedBox(
              width: finalGridWidth > 0 ? finalGridWidth : 0.0,
              height: finalGridHeight > 0 ? finalGridHeight : 0.0,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: gridCount,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                  childAspectRatio: targetAspectRatio,
                ),
                itemBuilder: (context, index) {
                  if (index < scenes.length) {
                    final scene = scenes[index];
                    final isProgram = scene.name == activeProgramScene;
                    final isPreview = studioModeEnabled && scene.name == activePreviewScene;

                    final tileContent = ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onSelectScene != null
                              ? () {
                                  Haptics.medium();
                                  onSelectScene!(scene.name);
                                }
                              : null,
                          onDoubleTap: onCutScene != null
                              ? () {
                                  Haptics.heavy();
                                  onCutScene!(scene.name);
                                }
                              : null,
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ScenePreviewBox(
                                sceneName: scene.name,
                                isProgram: isProgram,
                                isPreview: isPreview,
                                thumbnailBase64: scene.thumbnailBase64,
                                sceneIndex: index + 1,
                                showTallyBanner: true,
                                aspectRatio: 16 / 9,
                              ),
                              if (!isLocked)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: AppColors.surfaceBorderBold,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 9.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );

                    if (isLocked || onReorderScene == null) {
                      return tileContent;
                    }

                    return DragTarget<int>(
                      onWillAcceptWithDetails: (details) => details.data != index,
                      onAcceptWithDetails: (details) {
                        Haptics.medium();
                        onReorderScene!(details.data, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isDropTarget = candidateData.isNotEmpty;

                        final wrappedChild = Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: isDropTarget
                                ? Border.all(color: AppColors.accentCyan, width: 2.0)
                                : null,
                          ),
                          child: tileContent,
                        );

                        return LongPressDraggable<int>(
                          data: index,
                          delay: const Duration(milliseconds: 150),
                          onDragStarted: () => Haptics.selection(),
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: finalItemWidth,
                              height: finalItemHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: AppColors.accentCyan, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: ScenePreviewBox(
                                    sceneName: scene.name,
                                    isProgram: isProgram,
                                    isPreview: isPreview,
                                    thumbnailBase64: scene.thumbnailBase64,
                                    sceneIndex: index + 1,
                                    showTallyBanner: true,
                                    aspectRatio: 16 / 9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.25,
                            child: tileContent,
                          ),
                          child: wrappedChild,
                        );
                      },
                    );
                  }

                  // Standby unassigned channel feed slot (matches professional multiview walls)
                  final standbySlot = ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.surfaceBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_off_outlined,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'CH ${index + 1 < 10 ? '0${index + 1}' : '${index + 1}'}',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  if (isLocked || onReorderScene == null) {
                    return standbySlot;
                  }

                  return DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data < scenes.length,
                    onAcceptWithDetails: (details) {
                      Haptics.medium();
                      onReorderScene!(details.data, scenes.length - 1);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isDropTarget = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: isDropTarget
                              ? Border.all(color: AppColors.accentCyan, width: 2.0)
                              : null,
                        ),
                        child: standbySlot,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
