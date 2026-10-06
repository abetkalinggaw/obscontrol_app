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
import '../widgets/program_monitor.dart';
import '../widgets/scene_audio_monitor_bar.dart';
import '../widgets/scene_grid.dart';
import '../widgets/scene_preview_box.dart';

/// Pure Multiview Monitor Screen.
///
/// Designed strictly for non-interactive observation:
/// - Users cannot touch or tap to trigger scene switching or transitions.
/// - Shows master PRV (Preview, in Studio Mode) and PGM (Program) monitors with live transition view.
/// - Displays all scenes in a consistent 4 or 8 grid layout identical to SwitcherScreen.
/// - Grid layout switcher (4 / 8) is available in the console header.
class MultiviewOnlyScreen extends ConsumerWidget {
  const MultiviewOnlyScreen({super.key});

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
        icon: Icons.grid_view_rounded,
        title: 'Multiview Offline',
        subtitle: 'Connect to your OBS Studio or broadcasting software to monitor live multiview feeds.',
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
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            final fixedMasterHeight = isLandscape
                ? (availableHeight * 0.42).clamp(110.0, 180.0)
                : (availableHeight * 0.25).clamp(118.0, 148.0);

            return Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
              ),
              child: Column(
                children: [
                  // ── Multiview Header Row ──────────────────────────────
                  _buildHeaderRow(
                    ref: ref,
                    previewScene: previewScene,
                    programScene: programScene,
                    studioModeEnabled: studioModeEnabled,
                    gridCount: gridCount,
                  ),

                  const SizedBox(height: 6),

                  // ── Center Content Area ───────────────────────────────
                  // In landscape: Portrait vertical audio mixer level positioned on the left side
                  // of the master monitors and scene grid (preventing overlap with right controls).
                  // In portrait: Monitors & Grid stacked vertically with audio meter at the bottom.
                  Expanded(
                    child: isLandscape
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left: Portrait (Vertical) Audio Monitor VU Meter
                              const SceneAudioMonitorBar(isVertical: true),

                              const SizedBox(width: 8),

                              // Right: Master Monitors & Scene Monitor Grid
                              Expanded(
                                child: Column(
                                  children: [
                                    // Top: Master Monitors (Preview & Program / View Only)
                                    _buildMasterRow(
                                      height: fixedMasterHeight,
                                      studioModeEnabled: studioModeEnabled,
                                      previewScene: previewScene,
                                      programScene: programScene,
                                      previewThumbnail: previewThumbnail,
                                      programThumbnail: programThumbnail,
                                    ),

                                    // Flat Structural Divider
                                    _buildSectionDivider(),

                                    const SizedBox(height: 4),

                                    // Scene Monitor Grid (Non-interactive)
                                    Expanded(
                                      child: SceneGrid(
                                        scenes: scenesState.scenes,
                                        activeProgramScene: programScene,
                                        activePreviewScene: previewScene,
                                        studioModeEnabled: studioModeEnabled,
                                        isLocked: true, // Always locked against reordering
                                        padding: EdgeInsets.zero,
                                        gridCount: gridCount,
                                        crossAxisCount: 4,
                                        alignment: Alignment.topCenter,
                                        onSelectScene: null, // Touch disabled: view-only!
                                        onCutScene: null, // Touch disabled: view-only!
                                        onReorderScene: null, // Touch disabled: view-only!
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              // Top: Master Monitors (Preview & Program / View Only)
                              _buildMasterRow(
                                height: fixedMasterHeight,
                                studioModeEnabled: studioModeEnabled,
                                previewScene: previewScene,
                                programScene: programScene,
                                previewThumbnail: previewThumbnail,
                                programThumbnail: programThumbnail,
                              ),

                              // Flat Structural Divider
                              _buildSectionDivider(),

                              const SizedBox(height: 4),

                              // Scene Monitor Grid (Non-interactive)
                              Expanded(
                                child: SceneGrid(
                                  scenes: scenesState.scenes,
                                  activeProgramScene: programScene,
                                  activePreviewScene: previewScene,
                                  studioModeEnabled: studioModeEnabled,
                                  isLocked: true, // Always locked against reordering
                                  padding: EdgeInsets.zero,
                                  gridCount: gridCount,
                                  crossAxisCount: 2,
                                  alignment: Alignment.topCenter,
                                  onSelectScene: null, // Touch disabled: view-only!
                                  onCutScene: null, // Touch disabled: view-only!
                                  onReorderScene: null, // Touch disabled: view-only!
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Audio Monitor Meter Bar (Aligned under scene monitor grid in portrait)
                              const SceneAudioMonitorBar(isVertical: false),
                            ],
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
  }) {
    if (!studioModeEnabled) {
      return Row(
        children: [
          // Left: Live Program Indicator
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
          const Text(
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

          // 4/8 Grid Selector
          GridCountSelector(
            selectedCount: gridCount,
            onSelectCount: (c) =>
                ref.read(gridCountProvider.notifier).setCount(c),
            counts: const [4, 8],
          ),
        ],
      );
    }

    // Studio Mode: PRV & PGM telemetry labels
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
        const Text(
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

        // Center: 4/8 Grid Count Selector
        GridCountSelector(
          selectedCount: gridCount,
          onSelectCount: (c) =>
              ref.read(gridCountProvider.notifier).setCount(c),
          counts: const [4, 8],
        ),

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
        const Text(
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

  Widget _buildMasterRow({
    required double height,
    required bool studioModeEnabled,
    required String previewScene,
    required String programScene,
    String? previewThumbnail,
    String? programThumbnail,
  }) {
    if (!studioModeEnabled) {
      // Studio Mode OFF: Single centered 16:9 PROGRAM monitor
      return SizedBox(
        height: height,
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ScenePreviewBox(
              sceneName: programScene.isNotEmpty ? programScene : 'No Program',
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

    // Studio Mode ON: Dual 16:9 monitors side-by-side (PREVIEW left, PROGRAM right)
    return SizedBox(
      height: height,
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
          // PROGRAM (Red) - With live transition crossfade view
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
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1.0, color: AppColors.surfaceBorder),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'SCENE MONITOR',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1.0, color: AppColors.surfaceBorder),
          ),
        ],
      ),
    );
  }
}
