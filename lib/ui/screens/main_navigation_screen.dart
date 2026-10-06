import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';
import '../../providers/obs_provider.dart';
import '../dialogs/quick_connect_sheet.dart';
import '../widgets/floating_bars_insets.dart';
import '../widgets/liquid_glass_bottom_bar.dart';
import '../widgets/safe_action_dialog.dart';
import '../widgets/telemetry_header.dart';
import 'audio_mixer_screen.dart';
import 'connection_settings_screen.dart';
import 'landscape_multiview_screen.dart';
import 'multiview_only_screen.dart';
import 'switcher_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isTopBarCollapsed = false;
  bool _isLandscapeBarsVisible = false;

  final List<Widget> _portraitScreens = const [
    SwitcherScreen(),
    MultiviewOnlyScreen(),
    AudioMixerScreen(),
    ConnectionSettingsScreen(),
  ];

  final List<Widget> _landscapeScreens = const [
    LandscapeMultiviewScreen(),
    MultiviewOnlyScreen(),
    AudioMixerScreen(),
    ConnectionSettingsScreen(),
  ];

  void _onTabTapped(int index) {
    Haptics.selection();
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleLandscapeBars() {
    Haptics.selection();
    setState(() => _isLandscapeBarsVisible = !_isLandscapeBarsVisible);
  }

  void _toggleTopBarCollapse() {
    Haptics.selection();
    setState(() => _isTopBarCollapsed = !_isTopBarCollapsed);
  }

  void _handleToggleStream(bool isCurrentlyStreaming) async {
    if (isCurrentlyStreaming) {
      final confirmed = await SafeActionDialog.show(
        context,
        title: 'End Live Stream?',
        message: 'Are you sure you want to stop broadcasting live to your audience?',
        confirmLabel: 'END STREAM',
        confirmColor: AppColors.liveRed,
      );
      if (confirmed == true) {
        ref.read(obsProvider.notifier).toggleStream();
      }
    } else {
      ref.read(obsProvider.notifier).toggleStream();
    }
  }

  void _handleToggleRecord(bool isCurrentlyRecording) async {
    if (isCurrentlyRecording) {
      final confirmed = await SafeActionDialog.show(
        context,
        title: 'Stop Recording?',
        message: 'Are you sure you want to stop and save the current recording session?',
        confirmLabel: 'STOP RECORDING',
        confirmColor: AppColors.previewAmber,
      );
      if (confirmed == true) {
        ref.read(obsProvider.notifier).toggleRecord();
      }
    } else {
      ref.read(obsProvider.notifier).toggleRecord();
    }
  }

  void _handleSaveReplay() {
    ref.read(obsProvider.notifier).saveReplayBuffer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Replay clip buffer saved!'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  Widget _buildLandscapeControlsToggle() {
    final tooltipMessage = _isLandscapeBarsVisible
        ? 'Hide Topbar & Navigation'
        : 'Show Topbar & Navigation';

    return Tooltip(
      message: tooltipMessage,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('landscape_controls_toggle'),
          onTap: _toggleLandscapeBars,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _isLandscapeBarsVisible
                    ? AppColors.surfaceBorderBold
                    : AppColors.accentCyan.withValues(alpha: 0.7),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  _isLandscapeBarsVisible
                      ? Icons.fullscreen_rounded
                      : Icons.tune_rounded,
                  key: ValueKey<bool>(_isLandscapeBarsVisible),
                  size: 20,
                  color: _isLandscapeBarsVisible
                      ? AppColors.textPrimary
                      : AppColors.accentCyan,
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
    final obsState = ref.watch(obsProvider);

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          final header = TelemetryHeader(
            connectionStatus: obsState.status,
            stats: obsState.stats,
            isCollapsed: _isTopBarCollapsed,
            onToggleCollapse: _toggleTopBarCollapse,
            onOpenSettings: () {
              if (obsState.status == ObsConnectionStatus.disconnected ||
                  obsState.status == ObsConnectionStatus.error) {
                QuickConnectSheet.show(context);
              } else {
                setState(() => _currentIndex = 2);
              }
            },
            onToggleStream: () => _handleToggleStream(obsState.stats.isStreaming),
            onToggleRecord: () => _handleToggleRecord(obsState.stats.isRecording),
            onSaveReplay: _handleSaveReplay,
          );

          if (isLandscape) {
            final viewPadding = MediaQuery.viewPaddingOf(context);

            return Scaffold(
              backgroundColor: AppColors.background,
              body: Stack(
                children: [
                  // Full layout structure with animated Topbar & Navbar
                  Column(
                    children: [
                      // Top Telemetry Header
                      ClipRect(
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.bottomCenter,
                          heightFactor: _isLandscapeBarsVisible ? 1.0 : 0.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            opacity: _isLandscapeBarsVisible ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !_isLandscapeBarsVisible,
                              child: header,
                            ),
                          ),
                        ),
                      ),

                      // Screen Content (Switcher, Audio, Settings)
                      Expanded(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: _isLandscapeBarsVisible,
                          removeBottom: _isLandscapeBarsVisible,
                          child: SafeArea(
                            top: !_isLandscapeBarsVisible,
                            bottom: !_isLandscapeBarsVisible,
                            left: true,
                            right: true,
                            child: FloatingBarsInsets(
                              topInset: 0,
                              bottomInset: 0,
                              child: IndexedStack(
                                index: _currentIndex,
                                children: _landscapeScreens,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom Navigation Dock
                      ClipRect(
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          heightFactor: _isLandscapeBarsVisible ? 1.0 : 0.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            opacity: _isLandscapeBarsVisible ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !_isLandscapeBarsVisible,
                              child: LiquidGlassBottomBar(
                                currentIndex: _currentIndex,
                                onTap: _onTabTapped,
                                isLandscape: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Floating Controls Toggle Button with dynamic docked position
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    bottom: _isLandscapeBarsVisible
                        ? (54.0 + 8.0 + viewPadding.bottom)
                        : (12.0 + viewPadding.bottom),
                    right: 14.0 + viewPadding.right,
                    child: _buildLandscapeControlsToggle(),
                  ),
                ],
              ),
            );
          }

          // Portrait layout with docked top app bar & bottom navigation bar
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                header,
                Expanded(
                  child: FloatingBarsInsets(
                    topInset: 0,
                    bottomInset: 0,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _portraitScreens,
                    ),
                  ),
                ),
                LiquidGlassBottomBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                  isLandscape: false,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
