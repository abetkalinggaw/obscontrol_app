import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import 'scene_preview_box.dart';

class StudioPreviewCard extends StatelessWidget {
  final bool studioModeEnabled;
  final String programScene;
  final String previewScene;
  final VoidCallback? onToggleStudioMode;
  final VoidCallback onTriggerCut;
  final VoidCallback onTriggerFade;
  final bool isMultiview;
  final Widget? customHeaderAction;

  const StudioPreviewCard({
    super.key,
    required this.studioModeEnabled,
    required this.programScene,
    required this.previewScene,
    this.onToggleStudioMode,
    required this.onTriggerCut,
    required this.onTriggerFade,
    this.isMultiview = false,
    this.customHeaderAction,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 500 && size.width >= 600;

    final previewHeight = isCompact ? 80.0 : (size.height < 720 ? 100.0 : 125.0);

    if (!studioModeEnabled && !isMultiview) {
      // Normal Mode Card: Live Program Scene Visual Preview + Studio Toggle
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 2 : 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.all(isCompact ? 8 : 12),
              decoration: BoxDecoration(
                color: const Color(0xFF11121A).withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.liveRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.liveRed.withValues(alpha: 0.9),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'PROGRAM',
                        style: TextStyle(
                          color: AppColors.liveRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          programScene.isNotEmpty ? programScene : 'No Scene Selected',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Enable Studio Mode',
                        child: InkWell(
                          onTap: () {
                            Haptics.selection();
                            onToggleStudioMode?.call();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.previewAmber.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.previewAmber.withValues(alpha: 0.40),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.splitscreen_rounded, size: 16, color: AppColors.previewAmber),
                                SizedBox(width: 6),
                                Text(
                                  'STUDIO MODE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.previewAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 6 : 8),
                  // Live Visual Preview for Program
                  SizedBox(
                    height: previewHeight,
                    width: double.infinity,
                    child: ScenePreviewBox(
                      sceneName: programScene.isNotEmpty ? programScene : 'No Scene Selected',
                      isProgram: true,
                      isPreview: false,
                      aspectRatio: 16 / 9,
                      showTallyBanner: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Studio Mode: Side-by-side Preview (Amber) & Program (Red) visual monitors + Cut & Fade row
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 2 : 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFF11121A).withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with Studio Mode Title & Toggle / Multiview Title & Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isMultiview)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.liveRed.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.liveRed.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: AppColors.liveRed),
                                SizedBox(width: 4),
                                Text(
                                  'OBS MULTIVIEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: AppColors.liveRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'DIRECTOR MONITOR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      )
                    else
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.splitscreen_rounded, size: 16, color: AppColors.previewAmber),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'STUDIO MODE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (customHeaderAction != null)
                      customHeaderAction!
                    else if (onToggleStudioMode != null)
                      Semantics(
                        button: true,
                        label: 'Disable Studio Mode',
                        child: InkWell(
                          onTap: () {
                            Haptics.selection();
                            onToggleStudioMode!();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                            ),
                            child: const Text(
                              'DISABLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: isCompact ? 6 : 10),

                // Two Side-by-side Monitors with Scene Preview visuals
                Row(
                  children: [
                    // PREVIEW MONITOR (Amber Border & visual)
                    Expanded(
                      child: ScenePreviewBox(
                        sceneName: previewScene.isNotEmpty ? previewScene : 'Select Preview',
                        isPreview: true,
                        isProgram: false,
                        aspectRatio: 16 / 9,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // PROGRAM MONITOR (Red Border & visual)
                    Expanded(
                      child: ScenePreviewBox(
                        sceneName: programScene.isNotEmpty ? programScene : 'No Program',
                        isProgram: true,
                        isPreview: false,
                        aspectRatio: 16 / 9,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isCompact ? 6 : 10),

                // Transition Buttons: CUT and FADE
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Cut transition',
                        child: InkWell(
                          onTap: () {
                            Haptics.heavy();
                            onTriggerCut();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: isCompact ? 16 : 18, color: AppColors.textPrimary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CUT',
                                        style: TextStyle(
                                          fontSize: isCompact ? 12 : 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Fade transition',
                        child: InkWell(
                          onTap: () {
                            Haptics.heavy();
                            onTriggerFade();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.previewAmber.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.previewAmber.withValues(alpha: 0.50),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.previewAmber.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome, size: isCompact ? 16 : 18, color: AppColors.previewAmber),
                                      const SizedBox(width: 6),
                                      Text(
                                        'FADE (300ms)',
                                        style: TextStyle(
                                          fontSize: isCompact ? 11 : 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                          color: AppColors.previewAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
