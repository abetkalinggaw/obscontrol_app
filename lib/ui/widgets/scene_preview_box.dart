import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Flat Broadcast Scene Monitor Box.
///
/// Features strict 16:9 aspect ratio, clean flat borders,
/// bold channel index, and solid Program (Red) / Preview (Amber) signal tallies.
class ScenePreviewBox extends StatelessWidget {
  final String sceneName;
  final bool isProgram;
  final bool isPreview;
  final String? thumbnailBase64;
  final double aspectRatio;
  final Widget? overlay;
  final bool showTallyBanner;
  final int? sceneIndex;

  const ScenePreviewBox({
    super.key,
    required this.sceneName,
    this.isProgram = false,
    this.isPreview = false,
    this.thumbnailBase64,
    this.aspectRatio = 16 / 9,
    this.overlay,
    this.showTallyBanner = true,
    this.sceneIndex,
  });

  Color get _tallyColor {
    if (isProgram) return AppColors.liveRed;
    if (isPreview) return AppColors.previewAmber;
    return AppColors.surfaceBorder;
  }

  Widget _buildSyntheticPreview(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('game')) {
      return Stack(
        children: [
          Container(
            color: const Color(0xFF10141D),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: CustomPaint(painter: _GridPatternPainter()),
            ),
          ),
          const Center(
            child: Icon(Icons.control_camera_rounded, size: 24, color: AppColors.accentCyan),
          ),
        ],
      );
    } else if (lower.contains('cam')) {
      return Stack(
        children: [
          Container(
            color: const Color(0xFF141720),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: CustomPaint(painter: _RuleOfThirdsPainter()),
            ),
          ),
          Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.connectedGreen,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Center(
                child: Icon(Icons.videocam_rounded, size: 16, color: AppColors.connectedGreen),
              ),
            ),
          ),
        ],
      );
    } else if (lower.contains('share') || lower.contains('screen')) {
      return Container(
        color: const Color(0xFF12151D),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCodeLine(56, AppColors.accentCyan),
            const SizedBox(height: 5),
            _buildCodeLine(96, AppColors.previewAmber),
            const SizedBox(height: 5),
            _buildCodeLine(76, AppColors.liveRed),
          ],
        ),
      );
    } else if (lower.contains('brb') || lower.contains('intermission')) {
      return Container(
        color: const Color(0xFF1E1324),
        child: const Center(
          child: Icon(Icons.pause_circle_outline_rounded, size: 26, color: Colors.white54),
        ),
      );
    } else if (lower.contains('replay')) {
      return Container(
        color: const Color(0xFF101626),
        child: const Center(
          child: Icon(Icons.replay_rounded, size: 24, color: AppColors.accentCyan),
        ),
      );
    } else if (lower.contains('guest') || lower.contains('discord')) {
      return Container(
        color: const Color(0xFF131720),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2330),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.person_outline_rounded, size: 16, color: AppColors.accentPurple),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2330),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.headset_rounded, size: 16, color: AppColors.accentCyan),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (lower.contains('intro') || lower.contains('countdown')) {
      return Container(
        color: const Color(0xFF0C131F),
        child: const Center(
          child: Icon(Icons.schedule_rounded, size: 22, color: AppColors.previewAmber),
        ),
      );
    } else if (lower.contains('sponsor')) {
      return Container(
        color: const Color(0xFF1A1710),
        child: const Center(
          child: Icon(Icons.workspace_premium_outlined, size: 22, color: AppColors.previewAmber),
        ),
      );
    } else {
      return Container(
        color: const Color(0xFF13161F),
        child: const Center(
          child: Icon(Icons.movie_creation_outlined, size: 20, color: AppColors.textMuted),
        ),
      );
    }
  }

  Widget _buildCodeLine(double width, Color color) {
    return Container(
      width: width,
      height: 3.5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRealImage = thumbnailBase64 != null && thumbnailBase64!.isNotEmpty;
    final tallyBorderColor = _tallyColor;
    final borderWidth = (isProgram || isPreview) ? 1.5 : 1.0;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.obsidianBase,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: tallyBorderColor, width: borderWidth),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Scene Visual
              if (hasRealImage)
                Image.memory(
                  base64Decode(thumbnailBase64!),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              else
                _buildSyntheticPreview(sceneName),

              // 2. Custom Overlay if provided
              ?overlay,

              // 3. Flat Bottom Scene Banner (Tally, Index, Scene Name)
              if (showTallyBanner)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    color: const Color(0xFF11131A),
                    child: Row(
                      children: [
                        // Geometric Status Tally Dot
                        if (isProgram) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.liveRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ] else if (isPreview) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.previewAmber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],

                        // Bold Monospaced Geometric Index
                        if (sceneIndex != null) ...[
                          Text(
                            sceneIndex! < 10 ? '0$sceneIndex' : '$sceneIndex',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: isProgram
                                  ? AppColors.liveRed
                                  : (isPreview
                                      ? AppColors.previewAmber
                                      : AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],

                        // Crisp Geometric Scene Title
                        Expanded(
                          child: Text(
                            sceneName,
                            style: TextStyle(
                              color: (isProgram || isPreview)
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.8;

    final x1 = size.width / 3;
    final x2 = (size.width / 3) * 2;
    final y1 = size.height / 3;
    final y2 = (size.height / 3) * 2;

    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), paint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), paint);
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
