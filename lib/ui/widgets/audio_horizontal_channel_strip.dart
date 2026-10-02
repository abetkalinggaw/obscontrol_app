import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/obs_audio_source.dart';

/// OBS-style horizontal channel strip.
///
/// Features:
/// - Channel icon, name, formatted dB readout, and tactile mute button.
/// - Stereo horizontal VU meters (L & R) with OBS Studio color zones (green, yellow, red),
///   peak hold line, and dB scale tick markers.
/// - Smooth horizontal volume fader.
class AudioHorizontalChannelStrip extends StatelessWidget {
  final ObsAudioSource source;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  const AudioHorizontalChannelStrip({
    super.key,
    required this.source,
    required this.onVolumeChanged,
    required this.onToggleMute,
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

  @override
  Widget build(BuildContext context) {
    final isMuted = source.muted;
    final iconData = _getSourceIcon(source.name);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isMuted ? AppColors.liveRed.withValues(alpha: 0.6) : AppColors.surfaceBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Icon + Name + dB readout + Mute Button ───────
          Row(
            children: [
              Icon(
                isMuted ? Icons.mic_off_rounded : iconData,
                size: 13,
                color: isMuted ? AppColors.liveRed : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  source.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // dB readout
              Text(
                isMuted ? 'MUTED' : _formatDb(source.volumeDb),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isMuted ? AppColors.liveRed : AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),

              // Mute button
              Semantics(
                button: true,
                label: isMuted ? 'Unmute ${source.name}' : 'Mute ${source.name}',
                child: GestureDetector(
                  onTap: () {
                    Haptics.medium();
                    onToggleMute();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMuted ? AppColors.liveRed : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isMuted ? AppColors.liveRed : AppColors.surfaceBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: isMuted ? Colors.white : AppColors.textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isMuted ? 'MUTED' : 'MUTE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isMuted ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Horizontal Stereo VU Meters (L & R) ───────────────────
          Row(
            children: [
              const SizedBox(
                width: 12,
                child: Text(
                  'L',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 6,
                  child: RepaintBoundary(
                    child: _HorizontalVuBar(
                      level: isMuted ? 0.0 : source.leftLevel,
                      peak: isMuted ? 0.0 : source.peakHold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const SizedBox(
                width: 12,
                child: Text(
                  'R',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 6,
                  child: RepaintBoundary(
                    child: _HorizontalVuBar(
                      level: isMuted ? 0.0 : source.rightLevel,
                      peak: isMuted ? 0.0 : source.peakHold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // dB Scale tick markers under the VU meters
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 1),
            child: _HorizontalDbScale(),
          ),

          // ── Volume Fader Slider ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.5,
                      activeTrackColor: isMuted ? AppColors.textMuted : AppColors.accentCyan,
                      inactiveTrackColor: AppColors.surfaceElevated,
                      thumbColor: isMuted ? AppColors.textMuted : AppColors.textPrimary,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      overlayColor: AppColors.accentCyan.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: source.volumeMul.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: onVolumeChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(source.volumeMul * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal dB tick-mark scale matching OBS style.
class _HorizontalDbScale extends StatelessWidget {
  static const _ticks = [-60, -40, -30, -20, -10, -5, 0];

  const _HorizontalDbScale();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 11,
      child: CustomPaint(
        painter: _HorizontalDbScalePainter(ticks: _ticks),
      ),
    );
  }
}

class _HorizontalDbScalePainter extends CustomPainter {
  final List<int> ticks;
  const _HorizontalDbScalePainter({required this.ticks});

  double _dbToFrac(int db) {
    const minDb = -60.0;
    const maxDb = 0.0;
    return (db - minDb) / (maxDb - minDb);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted
      ..strokeWidth = 0.5;

    const textStyle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 6.5,
      fontWeight: FontWeight.w600,
    );

    for (final db in ticks) {
      final frac = _dbToFrac(db);
      final x = size.width * frac;

      // Draw tick line
      canvas.drawLine(Offset(x, 0), Offset(x, 2.5), paint);

      // Draw label
      final label = db == 0 ? '0' : '$db';
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final textX = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(textX, 2.5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Single horizontal VU bar with green→yellow→red color zones and peak hold line.
class _HorizontalVuBar extends StatelessWidget {
  final double level; // 0.0–1.0
  final double peak;  // 0.0–1.0

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
      ..strokeWidth = 0.8;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, bgPaint);
    canvas.drawRect(rect, borderPaint);

    if (level <= 0) return;

    final fillWidth = size.width * level;

    // Color zones — linear-in-dB mapping where 0dB=1.0, -60dB=0.0:
    //  0.00–0.85 (silence to -9 dB)  → green
    //  0.85–0.95 (-9 dB to -3 dB)    → yellow
    //  0.95–1.00 (-3 dB to  0 dB)    → red
    final greenStop = size.width * 0.85;
    final yellowStop = size.width * 0.95;

    // Green fill
    final greenRight = math.min(fillWidth, greenStop);
    if (greenRight > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, greenRight, size.height),
        Paint()..color = AppColors.vuGreen,
      );
    }

    // Yellow fill
    if (fillWidth > greenStop) {
      final yellowRight = math.min(fillWidth, yellowStop);
      canvas.drawRect(
        Rect.fromLTRB(greenStop, 0, yellowRight, size.height),
        Paint()..color = AppColors.vuYellow,
      );
    }

    // Red fill
    if (fillWidth > yellowStop) {
      canvas.drawRect(
        Rect.fromLTRB(yellowStop, 0, fillWidth, size.height),
        Paint()..color = AppColors.vuRed,
      );
    }

    // Peak hold line
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
