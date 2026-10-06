import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';
import '../../providers/obs_provider.dart';
import '../../providers/scenes_provider.dart';
import '../dialogs/quick_connect_sheet.dart';
import '../widgets/floating_bars_insets.dart';
import '../widgets/grid_count_selector.dart';
import '../widgets/obs_disconnected_prompt.dart';
import '../widgets/scene_grid.dart';
import '../widgets/scene_preview_box.dart';
import '../widgets/program_monitor.dart';
import '../widgets/studio_transition_control.dart';

/// Portrait Switcher Screen — Flat Broadcast Console.
///
/// Built with clean flat design:
/// - Crisp solid console chassis (no decorative blur or fuzzy shadows).
/// - Fixed-height master monitor section maintaining strict 16:9 ratio.
/// - Clear signal color hierarchy:
///     - Signal Red: PROGRAM, CUT, ON AIR
///     - Standby Amber: PREVIEW, FADE
///     - Slate Cyan: STUDIO, INTERACTIVE CONTROLS
/// - Clean hairline structural grid divider with uppercase typography.
/// - Scene grid anchored directly under the divider.
class SwitcherScreen extends ConsumerWidget {
  const SwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insets = FloatingBarsInsets.of(context);
    final obsState = ref.watch(obsProvider);
    final scenesState = ref.watch(scenesProvider);
    final isConnected = obsState.status == ObsConnectionStatus.connected;

    if (!isConnected) {
      return ObsDisconnectedPrompt(
        topInset: insets.topInset,
        bottomInset: insets.bottomInset,
        icon: Icons.wifi_off_rounded,
        title: 'Not Connected',
        subtitle: 'Connect to your OBS Studio, Streamlabs, or vMix setup '
            'on your local Wi-Fi to start switching.',
        onConnect: () {
          Haptics.medium();
          QuickConnectSheet.show(context);
        },
      );
    }

    final gridCount = ref.watch(gridCountProvider);
    final previewScene = scenesState.activePreviewScene;
    final programScene = scenesState.activeProgramScene;
    final studioModeEnabled = obsState.stats.studioModeEnabled;

    // Extract thumbnail data for the active PRV/PGM scenes from the scene list
    final programThumbnail = scenesState.scenes
        .where((s) => s.name == programScene)
        .map((s) => s.thumbnailBase64)
        .firstOrNull;
    final previewThumbnail = scenesState.scenes
        .where((s) => s.name == previewScene)
        .map((s) => s.thumbnailBase64)
        .firstOrNull;

    return SafeArea(
      left: true,
      right: true,
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          8,
          insets.topInset + 4,
          8,
          insets.bottomInset + 6,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;

            // Fixed constant top section height:
            // Does NOT jump when switching between 4 and 8 scene grid!
            final fixedMasterHeight =
                (availableHeight * 0.25).clamp(118.0, 148.0);

            return Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: AppColors.surfaceBorder,
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  // ── Console Header Row ───────────────────────────────
                  _buildHeaderRow(
                    ref: ref,
                    previewScene: previewScene,
                    programScene: programScene,
                    studioModeEnabled: studioModeEnabled,
                    gridCount: gridCount,
                    isLocked: scenesState.isLocked,
                  ),

                  const SizedBox(height: 6),

                  // ── Top: Master Monitors & Transitions Row ──────────
                  _buildMasterRow(
                    height: fixedMasterHeight,
                    studioModeEnabled: studioModeEnabled,
                    previewScene: previewScene,
                    programScene: programScene,
                    previewThumbnail: previewThumbnail,
                    programThumbnail: programThumbnail,
                    onCut: () => ref
                        .read(scenesProvider.notifier)
                        .triggerTransition('Cut'),
                    onFade: () => ref
                        .read(scenesProvider.notifier)
                        .triggerTransition('Fade'),
                  ),

                  // ── Flat Structural Divider ─────────────────────────
                  _buildSectionDivider(
                    isLocked: scenesState.isLocked,
                  ),

                  const SizedBox(height: 4),

                  // ── Bottom: Switcher Scene Grid (2 columns) ─────────
                  Expanded(
                    child: SceneGrid(
                      scenes: scenesState.scenes,
                      activeProgramScene: programScene,
                      activePreviewScene: previewScene,
                      studioModeEnabled: studioModeEnabled,
                      isLocked: scenesState.isLocked,
                      padding: EdgeInsets.zero,
                      gridCount: gridCount,
                      crossAxisCount: 2, // Exactly 2 columns in portrait
                      alignment: Alignment.topCenter,
                      onSelectScene: (sceneName) {
                        if (studioModeEnabled) {
                          ref
                              .read(scenesProvider.notifier)
                              .selectPreviewScene(sceneName);
                        } else {
                          ref
                              .read(scenesProvider.notifier)
                              .selectProgramScene(sceneName);
                        }
                      },
                      onCutScene: (sceneName) {
                        ref
                            .read(scenesProvider.notifier)
                            .selectProgramScene(sceneName);
                      },
                      onReorderScene: (oldIndex, newIndex) {
                        ref
                            .read(scenesProvider.notifier)
                            .reorderScenes(oldIndex, newIndex);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderRow({
    required WidgetRef ref,
    required String previewScene,
    required String programScene,
    required bool studioModeEnabled,
    required int gridCount,
    required bool isLocked,
  }) {
    if (!studioModeEnabled) {
      // Studio Mode OFF: Clean single live program indicator + Controls
      return Row(
        children: [
          // Left: Glowing Live Program dot + Label + Scene Name
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.liveRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'PROGRAM',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppColors.liveRed,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '/',
            style: TextStyle(
              color: AppColors.surfaceBorderBold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              programScene.isNotEmpty ? programScene : 'No Program',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Right: Studio Toggle + 4/8 Grid Selector + Lock Button
          _buildStudioToggleButton(ref, studioModeEnabled),
          const SizedBox(width: 6),
          GridCountSelector(
            selectedCount: gridCount,
            onSelectCount: (c) =>
                ref.read(gridCountProvider.notifier).setCount(c),
            counts: const [4, 8],
          ),
          const SizedBox(width: 6),
          _buildMultiviewLockButton(ref, isLocked),
        ],
      );
    }

    // Studio Mode ON: Preview (Yellow) & Program (Red) with centered controls
    return Row(
      children: [
        // Left: Yellow dot + PRV + Scene name
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.previewAmber,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'PRV',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AppColors.previewAmber,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '/',
          style: TextStyle(
            color: AppColors.surfaceBorderBold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            previewScene.isNotEmpty ? previewScene : 'Preview',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(width: 6),

        // Center: Studio Mode Toggle + 4/8 Grid Selector + Lock Button
        _buildStudioToggleButton(ref, studioModeEnabled),
        const SizedBox(width: 6),
        GridCountSelector(
          selectedCount: gridCount,
          onSelectCount: (c) =>
              ref.read(gridCountProvider.notifier).setCount(c),
          counts: const [4, 8],
        ),
        const SizedBox(width: 6),
        _buildMultiviewLockButton(ref, isLocked),

        const SizedBox(width: 6),

        // Right: Scene name + PGM + Red dot
        Expanded(
          child: Text(
            programScene.isNotEmpty ? programScene : 'Program',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '/',
          style: TextStyle(
            color: AppColors.surfaceBorderBold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'PGM',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AppColors.liveRed,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.liveRed,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildStudioToggleButton(WidgetRef ref, bool studioModeEnabled, {bool showLabel = false}) {
    return Tooltip(
      message: studioModeEnabled
          ? 'Studio Mode Enabled (tap to disable)'
          : 'Studio Mode Disabled (tap to enable)',
      child: InkWell(
        onTap: () {
          Haptics.selection();
          ref.read(obsProvider.notifier).toggleStudioMode();
        },
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: studioModeEnabled
                ? AppColors.accentCyan
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: studioModeEnabled
                  ? AppColors.accentCyan
                  : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.splitscreen_rounded,
                size: 11,
                color: studioModeEnabled
                    ? const Color(0xFF090A0E)
                    : AppColors.textMuted,
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  'STUDIO',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: studioModeEnabled
                        ? const Color(0xFF090A0E)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiviewLockButton(WidgetRef ref, bool isLocked, {bool showLabel = false}) {
    return Tooltip(
      message: isLocked ? 'Multiview Locked (tap to unlock)' : 'Multiview Unlocked (tap to lock)',
      child: InkWell(
        onTap: () {
          Haptics.medium();
          ref.read(scenesProvider.notifier).toggleMultiviewLock();
        },
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isLocked
                ? AppColors.previewAmber.withValues(alpha: 0.16)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isLocked
                  ? AppColors.previewAmber
                  : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 11,
                color: isLocked ? AppColors.previewAmber : AppColors.textMuted,
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  isLocked ? 'LOCK' : 'ARRANGE',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: isLocked ? AppColors.previewAmber : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterRow({
    required double height,
    required bool studioModeEnabled,
    required String previewScene,
    required String programScene,
    String? previewThumbnail,
    String? programThumbnail,
    required VoidCallback onCut,
    required VoidCallback onFade,
  }) {
    if (!studioModeEnabled) {
      // Studio Mode OFF: Single centered 16:9 PROGRAM monitor
      return SizedBox(
        height: height,
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ScenePreviewBox(
              sceneName:
                  programScene.isNotEmpty ? programScene : 'No Program',
              isProgram: true,
              isPreview: false,
              thumbnailBase64: programThumbnail,
              aspectRatio: 16 / 9,
              showTallyBanner: true,
            ),
          ),
        ),
      );
    }

    // Studio Mode ON: Dual 16:9 monitors side-by-side on top,
    // with StudioTransitionControl placed underneath.
    final dualMonitorsHeight = (height * 0.72).clamp(86.0, 110.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: dualMonitorsHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PREVIEW (Yellow)
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ScenePreviewBox(
                      sceneName: previewScene.isNotEmpty
                          ? previewScene
                          : 'Select Preview',
                      isPreview: true,
                      isProgram: false,
                      thumbnailBase64: previewThumbnail,
                      aspectRatio: 16 / 9,
                      showTallyBanner: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // PROGRAM (Red)
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ProgramMonitor(
                      programScene: programScene,
                      programThumbnail: programThumbnail,
                      previewScene: previewScene,
                      previewThumbnail: previewThumbnail,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // TRANSITION CONTROLS UNDER PRV & PGM (Icon-only CUT & FADE, Duration, T-Bar)
        StudioTransitionControl(
          direction: Axis.horizontal,
          onCut: onCut,
          onFade: onFade,
        ),
      ],
    );
  }

  Widget _buildSectionDivider({bool isLocked = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.0,
              color: AppColors.surfaceBorder,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isLocked ? AppColors.previewAmber : AppColors.accentCyan,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isLocked ? 'SCENES (LOCKED)' : 'SCENES',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: isLocked ? AppColors.previewAmber : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1.0,
              color: AppColors.surfaceBorder,
            ),
          ),
        ],
      ),
    );
  }
}

