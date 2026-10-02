import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  static bool enabled = true;

  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  static void alert() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}
