import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/obs_audio_source.dart';

/// OBS-style vertical VU meter — two narrow bars (L + R) side by side,
/// green → yellow → red from bottom to top, with dB tick marks.
class AudioChannelStrip extends StatelessWidget {
  final ObsAudioSource source;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  const AudioChannelStrip({
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

  @override
  Widget build(BuildContext context) {
    final isMuted = source.muted;
    final iconData = _getSourceIcon(source.name);

    return Container(
      width: 88,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isMuted ? AppColors.liveRed.withValues(alpha: 0.6) : AppColors.surfaceBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          // ── Channel name header ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              border: Border(
                bottom: BorderSide(
                  color: isMuted ? AppColors.liveRed.withValues(alpha: 0.5) : AppColors.surfaceBorder,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMuted ? Icons.mic_off_rounded : iconData,
                  size: 12,
                  color: isMuted ? AppColors.liveRed : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    source.name,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── VU meters + dB scale ─────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // dB scale labels
                  _DbScale(),
                  const SizedBox(width: 3),
                  // L channel
                  Expanded(
                    child: RepaintBoundary(
                      child: _VerticalVuBar(
                        level: isMuted ? 0.0 : source.leftLevel,
                        peak: isMuted ? 0.0 : source.peakHold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // R channel
                  Expanded(
                    child: RepaintBoundary(
                      child: _VerticalVuBar(
                        level: isMuted ? 0.0 : source.rightLevel,
                        peak: isMuted ? 0.0 : source.peakHold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── dB readout ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              isMuted ? 'MUTED' : _formatDb(source.volumeDb),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isMuted ? AppColors.liveRed : AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // ── Volume fader (vertical slider rotated) ───────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: isMuted ? AppColors.textMuted : AppColors.accentCyan,
                inactiveTrackColor: AppColors.surfaceElevated,
                thumbColor: isMuted ? AppColors.textMuted : AppColors.textPrimary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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

          // ── Mute button ──────────────────────────────────────
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
                margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                height: 28,
                decoration: BoxDecoration(
                  color: isMuted ? AppColors.liveRed : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isMuted ? AppColors.liveRed : AppColors.surfaceBorder,
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: isMuted ? Colors.white : AppColors.textSecondary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDb(double db) {
    if (db <= -60) return '-∞ dB';
    return '${db.toStringAsFixed(1)} dB';
  }
}

/// dB tick-mark scale along the left side of the VU column — matches OBS style.
class _DbScale extends StatelessWidget {
  // OBS shows: 0, -5, -10, -20, -30, -40, -60 (top to bottom)
  static const _ticks = [0, -5, -10, -20, -30, -40, -60];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: CustomPaint(
        painter: _DbScalePainter(ticks: _ticks),
      ),
    );
  }
}

class _DbScalePainter extends CustomPainter {
  final List<int> ticks;
  _DbScalePainter({required this.ticks});

  // Map a dB value to a 0-1 position (0 = bottom / silence, 1 = top / 0dB)
  double _dbToFrac(int db) {
    // OBS uses a roughly sqrt/log scale; we approximate with linear between -60 and 0
    const minDb = -60.0;
    const maxDb = 0.0;
    return (db - minDb) / (maxDb - minDb);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted
      ..strokeWidth = 0.5;

    final textStyle = const TextStyle(
      color: AppColors.textMuted,
      fontSize: 7,
      fontWeight: FontWeight.w600,
    );

    for (final db in ticks) {
      final frac = _dbToFrac(db);
      // y=0 is top (0dB), y=height is bottom (-60dB)
      final y = size.height * (1.0 - frac);

      // Draw tick line
      canvas.drawLine(Offset(size.width - 5, y), Offset(size.width, y), paint);

      // Draw label
      final label = db == 0 ? '0' : '$db';
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Single vertical VU bar with green→yellow→red color zones and peak hold line.
class _VerticalVuBar extends StatelessWidget {
  final double level; // 0.0–1.0
  final double peak;  // 0.0–1.0

  const _VerticalVuBar({required this.level, required this.peak});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalVuPainter(level: level.clamp(0.0, 1.0), peak: peak.clamp(0.0, 1.0)),
    );
  }
}

class _VerticalVuPainter extends CustomPainter {
  final double level;
  final double peak;

  _VerticalVuPainter({required this.level, required this.peak});

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

    // Filled height from bottom
    final fillHeight = size.height * level;
    final fillTop = size.height - fillHeight;

    // Color zones — linear-in-dB mapping where 0dB=1.0, -60dB=0.0:
    //  0.00–0.85 (silence to -9 dB)  → green
    //  0.85–0.95 (-9 dB to -3 dB)    → yellow
    //  0.95–1.00 (-3 dB to  0 dB)    → red
    // These exactly match OBS Studio's VU meter color zones.
    final greenStop = size.height * (1.0 - 0.85);   // y from top where green ends
    final yellowStop = size.height * (1.0 - 0.95);  // y from top where yellow ends

    // Green fill
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

    // Yellow fill
    if (fillTop < greenStop) {
      final yellowTop = math.max(fillTop, yellowStop);
      canvas.drawRect(
        Rect.fromLTRB(0, yellowTop, size.width, greenStop),
        Paint()..color = AppColors.vuYellow,
      );
    }

    // Red fill
    if (fillTop < yellowStop) {
      canvas.drawRect(
        Rect.fromLTRB(0, fillTop, size.width, yellowStop),
        Paint()..color = AppColors.vuRed,
      );
    }

    // Peak hold line
    if (peak > 0.02) {
      final peakY = size.height * (1.0 - peak);
      final peakColor = peak > 0.85 ? AppColors.vuRed : AppColors.textPrimary;
      canvas.drawRect(
        Rect.fromLTRB(0, peakY, size.width, peakY + 2),
        Paint()..color = peakColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalVuPainter old) =>
      old.level != level || old.peak != peak;
}
