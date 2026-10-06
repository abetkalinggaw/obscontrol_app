import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../providers/scenes_provider.dart';
import '../../providers/transition_mix_provider.dart';

/// A precision broadcast transition control center designed for Studio Mode.
///
/// Houses:
/// 1. Icon-only CUT (instant) and FADE buttons.
/// 2. Transition duration selector chip with quick presets and fine tuning modal.
/// 3. Tactile broadcast T-Bar manual transition slider matching OBS Studio.
class StudioTransitionControl extends ConsumerStatefulWidget {
  final VoidCallback onCut;
  final VoidCallback onFade;
  final double? width;
  final Axis direction;

  const StudioTransitionControl({
    super.key,
    required this.onCut,
    required this.onFade,
    this.width,
    this.direction = Axis.vertical,
  });

  @override
  ConsumerState<StudioTransitionControl> createState() =>
      _StudioTransitionControlState();
}

class _StudioTransitionControlState
    extends ConsumerState<StudioTransitionControl>
    with SingleTickerProviderStateMixin {
  static const double _kTbarHandleWidth = 14.0;
  static const double _kTbarHandleHeight = 30.0;
  static const double _kTbarTrackHeight = 20.0;

  double _tbarPosition = 0.0;
  bool _isDragging = false;
  bool _isCompleting = false;
  bool _isCoolingDown = false;
  bool _touchActive = false;
  int _lastHapticDetent = 0;
  Timer? _tbarThrottleTimer;
  Timer? _cooldownTimer;
  double? _pendingTbarPos;

  bool _animatingToCompletion = false;

  late final AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {
          _tbarPosition = _snapAnimation.value;
        });
        if (_animatingToCompletion) {
          _sendThrottledTBar(_tbarPosition, release: false);
        } else {
          ref.read(transitionMixProvider.notifier).setManual(_tbarPosition);
        }
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    _tbarThrottleTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _handleCut() {
    _snapController.stop();
    _cooldownTimer?.cancel();
    _isCompleting = false;
    _isCoolingDown = false;
    _animatingToCompletion = false;
    _isDragging = false;
    _touchActive = false;
    ref.read(transitionMixProvider.notifier).reset();
    _sendThrottledTBar(0.0, release: true);
    setState(() {
      _tbarPosition = 0.0;
    });
    widget.onCut();
  }

  void _handleFade() {
    _snapController.stop();
    _cooldownTimer?.cancel();
    _isCompleting = false;
    _isCoolingDown = false;
    _animatingToCompletion = false;
    _isDragging = false;
    _touchActive = false;
    final durationMs = ref.read(transitionDurationProvider);
    ref.read(transitionMixProvider.notifier).runAuto(durationMs);
    _sendThrottledTBar(0.0, release: true);
    setState(() {
      _tbarPosition = 0.0;
    });
    widget.onFade();
  }

  void _sendThrottledTBar(double pos, {bool release = false}) {
    if (release) {
      _tbarThrottleTimer?.cancel();
      _tbarThrottleTimer = null;
      _pendingTbarPos = null;
      ref.read(scenesProvider.notifier).setTBarPosition(pos, release: true);
      return;
    }

    _pendingTbarPos = pos;
    if (_tbarThrottleTimer != null && _tbarThrottleTimer!.isActive) return;

    // Send immediately on first change
    ref.read(scenesProvider.notifier).setTBarPosition(pos, release: false);
    _pendingTbarPos = null;

    // Stream subsequent updates at a steady ~30fps (33ms) cadence to avoid network packet pileup and frame drops
    _tbarThrottleTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pendingTbarPos != null) {
        final toSend = _pendingTbarPos!;
        _pendingTbarPos = null;
        ref.read(scenesProvider.notifier).setTBarPosition(toSend, release: false);
      } else if (!_isDragging && !_animatingToCompletion) {
        timer.cancel();
        _tbarThrottleTimer = null;
      }
    });
  }

  void _animateTo(
    double target, {
    Duration duration = const Duration(milliseconds: 180),
    Curve curve = Curves.easeOutCubic,
    VoidCallback? onDone,
  }) {
    _snapController.stop();
    _snapController.duration = duration;
    final start = _tbarPosition;
    _snapAnimation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: curve),
    );

    late void Function(AnimationStatus) statusListener;
    statusListener = (AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _snapController.removeStatusListener(statusListener);
        onDone?.call();
      }
    };

    _snapController.addStatusListener(statusListener);
    _snapController.forward(from: 0.0);
  }

  void _completeTransition() {
    if (_isCompleting || _isCoolingDown || !mounted) return;
    _isCompleting = true;
    _isDragging = false;
    Haptics.heavy();

    // Dynamically match cooldown delay to the configured transition duration (minimum 400ms)
    // to prevent the user from continuing to slide the handle while scenes settle
    final transitionDurationMs = ref.read(transitionDurationProvider);
    final cooldownDelayMs = math.max(transitionDurationMs, 400);

    void startCooldown() {
      if (!mounted) return;
      setState(() {
        _tbarPosition = 0.0;
        _isCompleting = false;
        _isCoolingDown = true;
      });

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(Duration(milliseconds: cooldownDelayMs), () {
        if (!mounted) return;
        if (!_touchActive) {
          setState(() {
            _isCoolingDown = false;
          });
        }
      });
    }

    if (_tbarPosition < 0.98) {
      // Glide the remaining distance to 1.0, commit, then reset handle to 0 instantly
      _animatingToCompletion = true;
      _animateTo(
        1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        onDone: () {
          if (!mounted) return;
          _animatingToCompletion = false;
          _snapController.stop();
          ref.read(transitionMixProvider.notifier).holdComplete();
          _sendThrottledTBar(1.0, release: true);
          startCooldown();
        },
      );
    } else {
      _animatingToCompletion = false;
      _snapController.stop();
      ref.read(transitionMixProvider.notifier).holdComplete();
      _sendThrottledTBar(1.0, release: true);
      startCooldown();
    }
  }

  void _handleDragDelta(double deltaDx, double trackWidth) {
    if (_isCompleting || _isCoolingDown || trackWidth <= _kTbarHandleWidth) return;
    final maxTravel = trackWidth - _kTbarHandleWidth;
    if (maxTravel <= 0) return;

    final deltaPos = deltaDx / maxTravel;
    final newPos = (_tbarPosition + deltaPos).clamp(0.0, 1.0);

    // Haptic detent feedback while sliding (every 10% transition increment)
    final detent = (newPos * 10).round();
    if (detent != _lastHapticDetent) {
      _lastHapticDetent = detent;
      Haptics.selection();
    }

    if (newPos >= 0.98) {
      _completeTransition();
      return;
    }

    setState(() {
      _tbarPosition = newPos;
    });

    ref.read(transitionMixProvider.notifier).setManual(newPos);
    _sendThrottledTBar(newPos, release: false);
  }

  void _handleDragEnd() {
    if (_isCompleting || _isCoolingDown) return;
    _isDragging = false;
    setState(() {});

    if (_tbarPosition >= 0.90) {
      // Completed transition to Program
      _completeTransition();
    } else if (_tbarPosition <= 0.10) {
      // Reverted to Preview
      Haptics.selection();
      _animatingToCompletion = false;
      _animateTo(
        0.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        onDone: () {
          if (!mounted) return;
          ref.read(transitionMixProvider.notifier).reset();
          _sendThrottledTBar(0.0, release: true);
          setState(() {
            _tbarPosition = 0.0;
          });
        },
      );
    } else {
      // User released in the middle: FREELY HOLD the transition at this position!
      Haptics.selection();
      ref.read(transitionMixProvider.notifier).setManual(_tbarPosition);
      _sendThrottledTBar(_tbarPosition, release: false);
    }
  }

  void _showDurationPicker(BuildContext context, int currentDuration) {
    Haptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: AppColors.surfaceBorder, width: 1),
      ),
      builder: (ctx) {
        return _TransitionDurationModal(
          initialDuration: currentDuration,
          onChanged: (newDuration) {
            ref
                .read(transitionDurationProvider.notifier)
                .setDuration(newDuration);
          },
        );
      },
    );
  }

  Widget _buildDurationButton(
    BuildContext context,
    int duration,
  ) {
    return Tooltip(
      message: 'Transition Duration: ${duration}ms',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('transition_duration_selector'),
          onTap: () => _showDurationPicker(context, duration),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${duration}ms',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 1),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = ref.watch(transitionDurationProvider);

    if (widget.direction == Axis.horizontal) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxAvailable = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 248.0;
          final controlWidth =
              (widget.width ?? 248.0).clamp(180.0, maxAvailable);

          return Center(
            child: SizedBox(
              width: controlWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Row 1: Action Buttons & Duration Selector (Triggers & Settings) ──
                  SizedBox(
                    height: 30,
                    child: _lockWhileTBar(Row(
                      children: [
                        // CUT Button (Icon only)
                        Expanded(
                          child: _TransitionIconButton(
                            key: const Key('transition_cut_button'),
                            tooltip: 'CUT',
                            icon: Icons.bolt_rounded,
                            iconColor: AppColors.textPrimary,
                            bgColor: AppColors.liveRed,
                            borderColor: AppColors.liveRed,
                            onTap: _handleCut,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // FADE Button (Icon only)
                        Expanded(
                          child: _TransitionIconButton(
                            key: const Key('transition_fade_button'),
                            tooltip: 'FADE',
                            icon: Icons.auto_awesome,
                            iconColor: const Color(0xFF0F1115),
                            bgColor: AppColors.previewAmber,
                            borderColor: AppColors.previewAmber,
                            onTap: _handleFade,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Transition Duration Settings Button
                        Expanded(
                          child: _buildDurationButton(
                            context,
                            duration,
                          ),
                        ),
                      ],
                    )),
                  ),

                  const SizedBox(height: 6),

                  // ── Row 2: OBS T-Bar Manual Transition Slider ───────────
                  // Matches the exact width of the triggers and settings container above
                  _buildTBarSlider(isHorizontal: true),
                ],
              ),
            ),
          );
        },
      );
    }

    final controlWidth = widget.width ?? 150.0;
    return SizedBox(
      width: controlWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── 1. Action Buttons: CUT, FADE & Duration Settings ────────
          SizedBox(
            height: 30,
            child: _lockWhileTBar(Row(
              children: [
                // CUT Button (Icon only)
                Expanded(
                  child: _TransitionIconButton(
                    key: const Key('transition_cut_button'),
                    tooltip: 'CUT',
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.textPrimary,
                    bgColor: AppColors.liveRed,
                    borderColor: AppColors.liveRed,
                    onTap: _handleCut,
                  ),
                ),
                const SizedBox(width: 5),
                // FADE Button (Icon only)
                Expanded(
                  child: _TransitionIconButton(
                    key: const Key('transition_fade_button'),
                    tooltip: 'FADE',
                    icon: Icons.auto_awesome,
                    iconColor: const Color(0xFF0F1115),
                    bgColor: AppColors.previewAmber,
                    borderColor: AppColors.previewAmber,
                    onTap: _handleFade,
                  ),
                ),
                const SizedBox(width: 5),
                // Transition Duration Settings Button (Same height and width, consistent style!)
                Expanded(
                  child: _buildDurationButton(context, duration),
                ),
              ],
            )),
          ),

          const SizedBox(height: 5),

          // ── 2. OBS T-Bar Manual Transition Slider ──────────────────
          _buildTBarSlider(isHorizontal: false),
        ],
      ),
    );
  }

  /// True while the T-Bar is being used (dragged, held mid-way, completing or cooling down).
  bool get _tbarBusy =>
      _isDragging || _isCompleting || _isCoolingDown || _touchActive || _tbarPosition > 0.0;

  /// Disables and dims the transition buttons / duration selector while the T-Bar is in use.
  Widget _lockWhileTBar(Widget child) {
    final busy = _tbarBusy;
    return IgnorePointer(
      ignoring: busy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: busy ? 0.35 : 1.0,
        child: child,
      ),
    );
  }

  Widget _buildTBarSlider({required bool isHorizontal}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxTravel = (trackWidth - _kTbarHandleWidth).clamp(
          0.0,
          1000.0,
        );
        final handleOffset = (_tbarPosition * maxTravel).clamp(
          0.0,
          maxTravel,
        );
        final isHeld = _tbarPosition > 0.05 && _tbarPosition < 0.95;

        return Container(
          width: trackWidth,
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Container(
            key: const Key('tbar_slider_track'),
            height: _kTbarTrackHeight,
            width: trackWidth,
            alignment: Alignment.centerLeft,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // ── Rail Slot / Groove ───────────────
                Center(
                            child: Container(
                              height: 6,
                              width: trackWidth,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C0E12),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: AppColors.surfaceBorderBold,
                                  width: 0.9,
                                ),
                              ),
                            ),
                          ),

                          // ── Unchanged Active Transition Fill ───────────
                          if (_tbarPosition > 0.01)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 6,
                                width: (handleOffset + (_kTbarHandleWidth / 2))
                                    .clamp(0.0, trackWidth),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.previewAmber,
                                      AppColors.liveRed,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // ── Broadcast T-Bar Handle (Finger-Accessible 44px Height, Outside Rail) ──
                          Positioned(
                            left: handleOffset,
                            width: _kTbarHandleWidth,
                            top: 0,
                            bottom: 0,
                            child: GestureDetector(
                              key: const Key('tbar_slider_handle'),
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (_) {
                                if (_isCompleting || _isCoolingDown) return;
                                _touchActive = true;
                                _snapController.stop();
                                _isDragging = true;
                                _lastHapticDetent = (_tbarPosition * 20).round();
                                Haptics.selection();
                                setState(() {});
                              },
                              onHorizontalDragUpdate: (details) {
                                if (_isCompleting || _isCoolingDown) return;
                                _handleDragDelta(details.delta.dx, trackWidth);
                              },
                              onHorizontalDragEnd: (_) {
                                _touchActive = false;
                                if (_isCompleting) return;
                                if (_isCoolingDown) {
                                  if (_cooldownTimer == null || !_cooldownTimer!.isActive) {
                                    setState(() {
                                      _isCoolingDown = false;
                                    });
                                  }
                                  return;
                                }
                                _handleDragEnd();
                              },
                              onHorizontalDragCancel: () {
                                _touchActive = false;
                                if (_isCompleting) return;
                                if (_isCoolingDown) {
                                  if (_cooldownTimer == null || !_cooldownTimer!.isActive) {
                                    setState(() {
                                      _isCoolingDown = false;
                                    });
                                  }
                                  return;
                                }
                                _handleDragEnd();
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: _isCoolingDown ? 0.6 : 1.0,
                                child: Center(
                                  child: Container(
                                    width: _kTbarHandleWidth,
                                    height: _kTbarHandleHeight,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: _isCoolingDown
                                            ? const [
                                                Color(0xFF222630),
                                                Color(0xFF161920),
                                                Color(0xFF0F1116),
                                              ]
                                            : _isDragging
                                                ? const [
                                                    Color(0xFF3E475A),
                                                    Color(0xFF242A36),
                                                    Color(0xFF181C24),
                                                  ]
                                                : (isHeld
                                                    ? const [
                                                        Color(0xFF363E4E),
                                                        Color(0xFF202530),
                                                        Color(0xFF161920),
                                                      ]
                                                    : const [
                                                        Color(0xFF2E3442),
                                                        Color(0xFF1C2028),
                                                        Color(0xFF13161C),
                                                      ]),
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _isCoolingDown
                                            ? const Color(0xFF3A4252)
                                            : _isDragging
                                                ? AppColors.accentCyan
                                                : (isHeld
                                                    ? AppColors.previewAmber
                                                    : const Color(0xFF5A6478)),
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        // Deep 3D drop shadow lifting handle off the rail
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 7,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 3),
                                        ),
                                        if (!_isCoolingDown && isHeld)
                                          BoxShadow(
                                            color: AppColors.previewAmber
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          )
                                        else if (!_isCoolingDown && _isDragging)
                                          BoxShadow(
                                            color: AppColors.accentCyan
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Top bevel specular highlight
                                        Positioned(
                                          top: 1.5,
                                          left: 3,
                                          right: 3,
                                          child: Container(
                                            height: 1.2,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6E7A94),
                                              borderRadius: BorderRadius.circular(
                                                1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Top knurl notch (T-Bar head grip)
                                        Positioned(
                                          top: 6,
                                          child: Container(
                                            width: 14,
                                            height: 1.2,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF434C60),
                                              borderRadius: BorderRadius.circular(
                                                1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Left tactile knurl rib
                                        Positioned(
                                          left: 6.5,
                                          top: 12,
                                          bottom: 12,
                                          child: Container(
                                            width: 1.5,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF475064),
                                              borderRadius: BorderRadius.circular(
                                                1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Center illuminated status tally needle
                                        Center(
                                          child: Container(
                                            width: 2.2,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _isCoolingDown
                                                  ? const Color(0xFF4A5568)
                                                  : _isDragging
                                                      ? AppColors.accentCyan
                                                      : (isHeld
                                                          ? AppColors.previewAmber
                                                          : const Color(
                                                              0xFFE2E8F0,
                                                            )),
                                              borderRadius: BorderRadius.circular(
                                                1,
                                              ),
                                              boxShadow: (!_isCoolingDown &&
                                                      (_isDragging || isHeld))
                                                  ? [
                                                      BoxShadow(
                                                        color: (_isDragging
                                                                ? AppColors
                                                                    .accentCyan
                                                                : AppColors
                                                                    .previewAmber)
                                                            .withValues(
                                                          alpha: 0.8,
                                                        ),
                                                        blurRadius: 5,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        // Right tactile knurl rib
                                        Positioned(
                                          right: 6.5,
                                          top: 12,
                                          bottom: 12,
                                          child: Container(
                                            width: 1.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF475064),
                                            borderRadius: BorderRadius.circular(
                                              1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Bottom knurl notch (T-Bar base grip)
                                      Positioned(
                                        bottom: 6,
                                        child: Container(
                                          width: 14,
                                          height: 1.2,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF434C60),
                                            borderRadius: BorderRadius.circular(
                                              1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Bottom subtle bevel
                                      Positioned(
                                        bottom: 1.5,
                                        left: 3,
                                        right: 3,
                                        child: Container(
                                          height: 1.0,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF262C38),
                                            borderRadius: BorderRadius.circular(
                                              1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      ),
                    ),
                  );
      },
    );
  }
}

class _TransitionIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;
  final String tooltip;

  const _TransitionIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Center(child: Icon(icon, size: 15, color: iconColor)),
          ),
        ),
      ),
    );
  }
}

class _TransitionDurationModal extends StatefulWidget {
  final int initialDuration;
  final ValueChanged<int> onChanged;

  const _TransitionDurationModal({
    required this.initialDuration,
    required this.onChanged,
  });

  @override
  State<_TransitionDurationModal> createState() =>
      _TransitionDurationModalState();
}

class _TransitionDurationModalState extends State<_TransitionDurationModal> {
  late int _duration;

  static const List<int> _presets = [100, 200, 300, 500, 750, 1000, 1500, 2000];

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Grabber & Header
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorderBold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TRANSITION DURATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    '$_duration ms',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: AppColors.previewAmber,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick Preset Chips
            const Text(
              'QUICK PRESETS',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final isSelected = _duration == preset;
                return InkWell(
                  onTap: () {
                    Haptics.selection();
                    setState(() => _duration = preset);
                    widget.onChanged(preset);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.previewAmber.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.previewAmber
                            : AppColors.surfaceBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      '${preset}ms',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: isSelected
                            ? AppColors.previewAmber
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Fine Adjustment Slider
            const Text(
              'FINE ADJUSTMENT',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.6,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.previewAmber,
                inactiveTrackColor: AppColors.surfaceElevated,
                thumbColor: AppColors.previewAmber,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _duration.clamp(50, 3000).toDouble(),
                min: 50,
                max: 3000,
                divisions: 59, // 50ms steps
                onChanged: (val) {
                  final rounded = (val / 50).round() * 50;
                  setState(() => _duration = rounded);
                  widget.onChanged(rounded);
                },
              ),
            ),

            const SizedBox(height: 8),

            // Close button
            ElevatedButton(
              onPressed: () {
                Haptics.selection();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: AppColors.surfaceBorder),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'DONE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
