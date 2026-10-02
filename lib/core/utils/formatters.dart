import 'dart:math' as math;

class Formatters {
  Formatters._();

  /// Formats duration in seconds to HH:mm:ss or mm:ss
  static String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Formats FPS to 1 decimal place e.g. "60.0"
  static String formatFps(double fps) {
    return fps.toStringAsFixed(1);
  }

  /// Converts a linear volume factor (0.0 - 1.0) to decibels (dB)
  /// OBS uses log10(mul) * 20
  static double volumeMultiplierToDb(double mul) {
    if (mul <= 0.00001) return -100.0;
    final db = 20.0 * (math.log(mul) / math.ln10);
    return db.clamp(-100.0, 0.0);
  }

  /// Converts dB back to linear multiplier
  static double dbToVolumeMultiplier(double db) {
    if (db <= -100.0) return 0.0;
    return math.pow(10.0, db / 20.0).toDouble().clamp(0.0, 1.0);
  }

  /// Formats dB for display e.g. "-6.2 dB" or "0.0 dB" or "-∞ dB"
  static String formatDb(double db) {
    if (db <= -60.0) return '-∞ dB';
    return '${db >= 0 ? '+' : ''}${db.toStringAsFixed(1)} dB';
  }

  /// Formats dropped frames percentage
  static String formatDroppedFrames(int dropped, int total) {
    if (total <= 0) return '$dropped (0.0%)';
    final pct = (dropped / total) * 100;
    return '$dropped (${pct.toStringAsFixed(1)}%)';
  }

  /// Formats a DateTime into human-readable relative time (e.g. "Just now", "5 mins ago")
  static String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.isNegative || diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    } else {
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '${dt.year}-$month-$day';
    }
  }
}
