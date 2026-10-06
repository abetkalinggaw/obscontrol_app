import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Visual state of an in-progress transition on the PROGRAM monitor.
class TransitionMix {
  /// 0.0 = outgoing Program fully visible, 1.0 = incoming scene fully visible.
  final double progress;

  /// Increments every time a new transition begins, so monitors know when to
  /// snapshot the outgoing/incoming scenes.
  final int generation;

  const TransitionMix(this.progress, this.generation);

  bool get active => progress > 0.0;
}

/// Local visual mix used to render OBS-style transitions on the app's PROGRAM
/// monitor. Driven by the T-Bar (manual) and the FADE button (auto).
class TransitionMixNotifier extends Notifier<TransitionMix> {
  Timer? _autoTimer;
  Timer? _holdTimer;
  bool _holding = false;

  @override
  TransitionMix build() {
    ref.onDispose(() {
      _autoTimer?.cancel();
      _holdTimer?.cancel();
    });
    return const TransitionMix(0.0, 0);
  }

  int _genFor(double next) {
    final starting = (state.progress <= 0.0 || _holding) && next > 0.0;
    return starting ? state.generation + 1 : state.generation;
  }

  /// Manual T-Bar position.
  void setManual(double value) {
    _autoTimer?.cancel();
    final v = value.clamp(0.0, 1.0);
    final gen = _genFor(v);
    _holdTimer?.cancel();
    _holding = false;
    state = TransitionMix(v, gen);
  }

  /// Transition committed: stay on the incoming scene briefly while OBS
  /// reports the new Program scene and its thumbnail settles.
  void holdComplete() {
    _autoTimer?.cancel();
    _holding = true;
    state = TransitionMix(1.0, state.generation);
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 700), reset);
  }

  /// Animated auto transition (FADE button), matching OBS's duration.
  void runAuto(int durationMs) {
    _autoTimer?.cancel();
    _holdTimer?.cancel();
    final gen = state.generation + 1;
    _holding = false;
    final total = durationMs <= 0 ? 1 : durationMs;
    final sw = Stopwatch()..start();
    state = TransitionMix(0.0001, gen);
    _autoTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final p = sw.elapsedMilliseconds / total;
      if (p >= 1.0) {
        t.cancel();
        holdComplete();
      } else {
        // Smooth ease-in-out like OBS's fade.
        state = TransitionMix((p * p * (3 - 2 * p)).clamp(0.0001, 1.0), gen);
      }
    });
  }

  void reset() {
    _autoTimer?.cancel();
    _holdTimer?.cancel();
    _holding = false;
    state = TransitionMix(0.0, state.generation);
  }
}

final transitionMixProvider =
    NotifierProvider<TransitionMixNotifier, TransitionMix>(TransitionMixNotifier.new);
