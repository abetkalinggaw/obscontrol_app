import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/obs_audio_source.dart';
import '../../providers/audio_provider.dart';

/// Broadcast Audio Monitor Meter designed for horizontal or vertical (portrait) orientation.
///
/// Features:
/// - Channel selector pill (shows 1 audio source at a time with dropdown or tap-to-cycle).
/// - Stereo VU meters (L & R) with OBS Studio broadcast color zones (green, yellow, red).
/// - Peak hold indicators and formatted live dB readout.
/// - Crisp, compact flat broadcast layout that fits neatly at bottom edge or on the right side.
class SceneAudioMonitorBar extends ConsumerWidget {
  final bool isVertical;

  const SceneAudioMonitorBar({
    super.key,
    this.isVertical = false,
  });

  IconData _getSourceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('mic') || lower.contains('aux')) return Icons.mic_none_rounded;
    if (lower.contains('spotify') || lower.contains('music') || lower.contains('bgm')) return Icons.music_note_rounded;
    if (lower.contains('discord') || lower.contains('call') || lower.contains('chat')) return Icons.headset_rounded;
    if (lower.contains('game')) return Icons.sports_esports_rounded;
    return Icons.volume_up_rounded;
  }

  String _formatDb(double db) {
    if (db <= -60) return '-∞ dB';
    return '${db.toStringAsFixed(1)} dB';
  }

  void _showSourcePicker(BuildContext context, WidgetRef ref, List<ObsAudioSource> sources, String? selectedName) {
    Haptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: AppColors.surfaceBorder, width: 1),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.accentCyan),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'MONITOR AUDIO SOURCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${sources.length} SOURCES',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 12, color: AppColors.surfaceBorder),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sources.length,
                    itemBuilder: (context, index) {
                      final src = sources[index];
                      final isSelected = src.name == selectedName;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          src.muted ? Icons.mic_off_rounded : _getSourceIcon(src.name),
                          size: 16,
                          color: isSelected ? AppColors.accentCyan : AppColors.textMuted,
                        ),
                        title: Text(
                          src.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          src.muted ? 'Muted' : _formatDb(src.volumeDb),
                          style: TextStyle(
                            fontSize: 10,
                            color: src.muted ? AppColors.liveRed : AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, size: 16, color: AppColors.accentCyan)
                            : null,
                        onTap: () {
                          Haptics.selection();
                          ref.read(monitoredAudioChannelProvider.notifier).selectChannel(src.name);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final sources = audioState.sources;
    final selectedChannelName = ref.watch(monitoredAudioChannelProvider);

    if (sources.isEmpty) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_off_rounded, size: 12, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              'No audio sources available',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final activeSource = sources.firstWhere(
      (s) => s.name == selectedChannelName,
      orElse: () => sources.first,
    );

    final isMuted = activeSource.muted;
    final iconData = isMuted ? Icons.mic_off_rounded : _getSourceIcon(activeSource.name);

    if (isVertical) {
      return _buildVerticalLayout(context, ref, activeSource, sources, isMuted, iconData);
    }

    return _buildHorizontalLayout(context, ref, activeSource, sources, isMuted, iconData);
  }

  Widget _buildHorizontalLayout(
    BuildContext context,
    WidgetRef ref,
    ObsAudioSource activeSource,
    List<ObsAudioSource> sources,
    bool isMuted,
    IconData iconData,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isMuted ? AppColors.liveRed.withValues(alpha: 0.6) : AppColors.surfaceBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // ── Source Selector Button ──────────────────────────────
          InkWell(
            onTap: () => _showSourcePicker(context, ref, sources, activeSource.name),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMuted
                    ? AppColors.liveRed.withValues(alpha: 0.15)
                    : AppColors.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isMuted
                      ? AppColors.liveRed.withValues(alpha: 0.5)
                      : AppColors.accentCyan.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 11,
                    color: isMuted ? AppColors.liveRed : AppColors.accentCyan,
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 86),
                    child: Text(
                      activeSource.name,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isMuted ? AppColors.liveRed : AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 13,
                    color: isMuted ? AppColors.liveRed : AppColors.accentCyan,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Dual VU Meter Bars (L & R stacked) ─────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text(
                      'L',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 5,
                        child: RepaintBoundary(
                          child: _HorizontalVuBar(
                            level: isMuted ? 0.0 : activeSource.leftLevel,
                            peak: isMuted ? 0.0 : activeSource.peakHold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      'R',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 5,
                        child: RepaintBoundary(
                          child: _HorizontalVuBar(
                            level: isMuted ? 0.0 : activeSource.rightLevel,
                            peak: isMuted ? 0.0 : activeSource.peakHold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Live dB Readout ────────────────────────────────────
          SizedBox(
            width: 46,
            child: Text(
              isMuted ? 'MUTED' : _formatDb(activeSource.volumeDb),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isMuted ? AppColors.liveRed : AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalLayout(
    BuildContext context,
    WidgetRef ref,
    ObsAudioSource activeSource,
    List<ObsAudioSource> sources,
    bool isMuted,
    IconData iconData,
  ) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isMuted ? AppColors.liveRed.withValues(alpha: 0.6) : AppColors.surfaceBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // ── Source Selector Button ──────────────────────────────
          InkWell(
            onTap: () => _showSourcePicker(context, ref, sources, activeSource.name),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              decoration: BoxDecoration(
                color: isMuted
                    ? AppColors.liveRed.withValues(alpha: 0.15)
                    : AppColors.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isMuted
                      ? AppColors.liveRed.withValues(alpha: 0.5)
                      : AppColors.accentCyan.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 11,
                    color: isMuted ? AppColors.liveRed : AppColors.accentCyan,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeSource.name,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isMuted ? AppColors.liveRed : AppColors.textPrimary,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 5),

          // ── Dual Vertical VU Meters (L & R columns side-by-side) ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // L Meter
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'L',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: RepaintBoundary(
                          child: _VerticalMonitorVuBar(
                            level: isMuted ? 0.0 : activeSource.leftLevel,
                            peak: isMuted ? 0.0 : activeSource.peakHold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                // R Meter
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'R',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: RepaintBoundary(
                          child: _VerticalMonitorVuBar(
                            level: isMuted ? 0.0 : activeSource.rightLevel,
                            peak: isMuted ? 0.0 : activeSource.peakHold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Live dB Readout at bottom ──────────────────────────
          Text(
            isMuted ? 'MUTE' : _formatDb(activeSource.volumeDb),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: isMuted ? AppColors.liveRed : AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HorizontalVuBar extends StatelessWidget {
  final double level;
  final double peak;

  const _HorizontalVuBar({required this.level, required this.peak});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HorizontalVuPainter(
        level: level.clamp(0.0, 1.0),
        peak: peak.clamp(0.0, 1.0),
      ),
    );
  }
}

class _HorizontalVuPainter extends CustomPainter {
  final double level;
  final double peak;

  _HorizontalVuPainter({required this.level, required this.peak});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.backgroundDeep;
    final borderPaint = Paint()
      ..color = AppColors.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, bgPaint);
    canvas.drawRect(rect, borderPaint);

    if (level <= 0) return;

    final fillWidth = size.width * level;

    // OBS Studio broadcast color zones:
    // 0.00 - 0.85 (-60dB to -9dB)  -> Green
    // 0.85 - 0.95 (-9dB to -3dB)   -> Yellow
    // 0.95 - 1.00 (-3dB to 0dB)    -> Red
    final greenStop = size.width * 0.85;
    final yellowStop = size.width * 0.95;

    final greenRight = math.min(fillWidth, greenStop);
    if (greenRight > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, greenRight, size.height),
        Paint()..color = AppColors.vuGreen,
      );
    }

    if (fillWidth > greenStop) {
      final yellowRight = math.min(fillWidth, yellowStop);
      canvas.drawRect(
        Rect.fromLTRB(greenStop, 0, yellowRight, size.height),
        Paint()..color = AppColors.vuYellow,
      );
    }

    if (fillWidth > yellowStop) {
      canvas.drawRect(
        Rect.fromLTRB(yellowStop, 0, fillWidth, size.height),
        Paint()..color = AppColors.vuRed,
      );
    }

    if (peak > 0.02) {
      final peakX = (size.width * peak).clamp(0.0, size.width - 2.0);
      final peakColor = peak > 0.85 ? AppColors.vuRed : AppColors.textPrimary;
      canvas.drawRect(
        Rect.fromLTRB(peakX, 0, peakX + 2, size.height),
        Paint()..color = peakColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalVuPainter old) =>
      old.level != level || old.peak != peak;
}

class _VerticalMonitorVuBar extends StatelessWidget {
  final double level;
  final double peak;

  const _VerticalMonitorVuBar({required this.level, required this.peak});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalMonitorVuPainter(
        level: level.clamp(0.0, 1.0),
        peak: peak.clamp(0.0, 1.0),
      ),
    );
  }
}

class _VerticalMonitorVuPainter extends CustomPainter {
  final double level;
  final double peak;

  _VerticalMonitorVuPainter({required this.level, required this.peak});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.backgroundDeep;
    final borderPaint = Paint()
      ..color = AppColors.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, bgPaint);
    canvas.drawRect(rect, borderPaint);

    if (level <= 0) return;

    final fillHeight = size.height * level;
    final fillTop = size.height - fillHeight;

    // OBS Studio broadcast color zones:
    // 0.00 - 0.85 (-60dB to -9dB)  -> Green
    // 0.85 - 0.95 (-9dB to -3dB)   -> Yellow
    // 0.95 - 1.00 (-3dB to 0dB)    -> Red
    final greenStop = size.height * (1.0 - 0.85);
    final yellowStop = size.height * (1.0 - 0.95);

    // Green fill (bottom zone)
    if (fillTop < size.height) {
      final greenBottom = size.height;
      final greenTop = math.max(fillTop, greenStop);
      if (greenTop < greenBottom) {
        canvas.drawRect(
          Rect.fromLTRB(0, greenTop, size.width, greenBottom),
          Paint()..color = AppColors.vuGreen,
        );
      }
    }

    // Yellow fill (mid zone)
    if (fillTop < greenStop) {
      final yellowTop = math.max(fillTop, yellowStop);
      canvas.drawRect(
        Rect.fromLTRB(0, yellowTop, size.width, greenStop),
        Paint()..color = AppColors.vuYellow,
      );
    }

    // Red fill (peak zone)
    if (fillTop < yellowStop) {
      canvas.drawRect(
        Rect.fromLTRB(0, fillTop, size.width, yellowStop),
        Paint()..color = AppColors.vuRed,
      );
    }

    // Peak hold line
    if (peak > 0.02) {
      final peakY = (size.height * (1.0 - peak)).clamp(0.0, size.height - 2.0);
      final peakColor = peak > 0.85 ? AppColors.vuRed : AppColors.textPrimary;
      canvas.drawRect(
        Rect.fromLTRB(0, peakY, size.width, peakY + 2),
        Paint()..color = peakColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalMonitorVuPainter old) =>
      old.level != level || old.peak != peak;
}

