import 'package:flutter/material.dart';

/// InheritedWidget providing top and bottom safe insets for screens
/// situated underneath floating liquid glass bars.
class FloatingBarsInsets extends InheritedWidget {
  final double topInset;
  final double bottomInset;

  const FloatingBarsInsets({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required super.child,
  });

  static FloatingBarsInsets of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FloatingBarsInsets>() ??
        const FloatingBarsInsets(
          topInset: 130.0,
          bottomInset: 78.0,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(FloatingBarsInsets oldWidget) {
    return topInset != oldWidget.topInset || bottomInset != oldWidget.bottomInset;
  }
}
