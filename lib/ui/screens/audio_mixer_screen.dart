import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/connection_state.dart';
import '../../providers/audio_provider.dart';
import '../../providers/obs_provider.dart';
import '../dialogs/audio_channel_visibility_dialog.dart';
import '../dialogs/quick_connect_sheet.dart';
import '../widgets/audio_channel_strip.dart';
import '../widgets/audio_horizontal_channel_strip.dart';
import '../widgets/floating_bars_insets.dart';

class AudioMixerScreen extends ConsumerWidget {
  const AudioMixerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insets = FloatingBarsInsets.of(context);
    final obsState = ref.watch(obsProvider);
    final audioState = ref.watch(audioProvider);
    final viewMode = ref.watch(audioViewModeProvider);
    final hiddenChannels = ref.watch(hiddenAudioChannelsProvider);
    final isConnected = obsState.status == ObsConnectionStatus.connected;

    if (!isConnected) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            28,
            insets.topInset,
            28,
            insets.bottomInset,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.surfaceBorder,
                    width: 1.0,
                  ),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: AppColors.textSecondary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Audio Mixer Inactive',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect to your streaming software to adjust faders, monitor stereo VU meters, and control audio channels.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Haptics.medium();
                    QuickConnectSheet.show(context);
                  },
                  icon: const Icon(Icons.link_rounded, size: 20),
                  label: const Text(
                    'CONNECT CONTROLLER',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (audioState.sources.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            28,
            insets.topInset,
            28,
            insets.bottomInset,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_none_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'No Audio Inputs Detected',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allSources = audioState.sources;
    final visibleSources = allSources.where((s) => !hiddenChannels.contains(s.name)).toList();
    final hasHiddenChannels = hiddenChannels.isNotEmpty &&
        allSources.any((s) => hiddenChannels.contains(s.name));

    return Column(
      children: [
        // ── Header bar ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(14, insets.topInset + 6, 14, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.equalizer_rounded,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasHiddenChannels
                        ? '${visibleSources.length}/${allSources.length} CHANNELS'
                        : '${allSources.length} CHANNELS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Channel visibility filter button
                  _buildVisibilityButton(context, hasHiddenChannels),
                  const SizedBox(width: 6),

                  // View mode toggle selector (Horizontal vs Vertical view - ICON ONLY)
                  _buildViewModeSelector(ref, viewMode),
                  const SizedBox(width: 6),

                  // MUTE ALL / UNMUTE ALL
                  TextButton(
                    onPressed: visibleSources.isEmpty
                        ? null
                        : () {
                            Haptics.heavy();
                            final anyUnmuted = visibleSources.any(
                              (s) => !s.muted,
                            );
                            for (final source in visibleSources) {
                              if (anyUnmuted && !source.muted) {
                                ref
                                    .read(audioProvider.notifier)
                                    .toggleMute(source.name);
                              } else if (!anyUnmuted && source.muted) {
                                ref
                                    .read(audioProvider.notifier)
                                    .toggleMute(source.name);
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      visibleSources.any((s) => !s.muted)
                          ? 'MUTE ALL'
                          : 'UNMUTE ALL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: visibleSources.isEmpty
                            ? AppColors.textMuted
                            : AppColors.previewAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Audio Channel Strips ─────────────────────────────────
        Expanded(
          child: visibleSources.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.surfaceBorder,
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.visibility_off_rounded,
                            size: 24,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'All Channels Hidden',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All audio channels are currently hidden from the mixer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: () {
                                Haptics.selection();
                                ref
                                    .read(hiddenAudioChannelsProvider.notifier)
                                    .showAll();
                              },
                              icon: const Icon(Icons.visibility_rounded, size: 14),
                              label: const Text(
                                'SHOW ALL',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentCyan,
                                foregroundColor: AppColors.background,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  AudioChannelVisibilitySheet.show(context),
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: const Text(
                                'MANAGE',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                    color: AppColors.surfaceBorderBold, width: 1.2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : viewMode == AudioMixerViewMode.vertical
                  // Vertical View: Channel strips scrolling horizontally
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          EdgeInsets.fromLTRB(8, 0, 8, insets.bottomInset + 8),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: visibleSources.map((source) {
                            return AudioChannelStrip(
                              key: ValueKey(source.name),
                              source: source,
                              onVolumeChanged: (val) {
                                ref
                                    .read(audioProvider.notifier)
                                    .setVolume(source.name, val);
                              },
                              onToggleMute: () {
                                ref
                                    .read(audioProvider.notifier)
                                    .toggleMute(source.name);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  // Horizontal View: Channel strips stacked vertically in a scrollable list
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        10,
                        4,
                        10,
                        insets.bottomInset + 8,
                      ),
                      itemCount: visibleSources.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final source = visibleSources[index];
                        return AudioHorizontalChannelStrip(
                          key: ValueKey(source.name),
                          source: source,
                          onVolumeChanged: (val) {
                            ref
                                .read(audioProvider.notifier)
                                .setVolume(source.name, val);
                          },
                          onToggleMute: () {
                            ref
                                .read(audioProvider.notifier)
                                .toggleMute(source.name);
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildVisibilityButton(BuildContext context, bool hasHidden) {
    return Semantics(
      button: true,
      label: 'Select Visible Audio Channels',
      child: Tooltip(
        message: 'Show/Hide Audio Channels',
        child: GestureDetector(
          onTap: () => AudioChannelVisibilitySheet.show(context),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: hasHidden
                  ? AppColors.accentCyan.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: hasHidden ? AppColors.accentCyan : AppColors.surfaceBorder,
                width: 1.0,
              ),
            ),
            child: Icon(
              hasHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 13,
              color: hasHidden ? AppColors.accentCyan : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeSelector(WidgetRef ref, AudioMixerViewMode currentMode) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeOption(
            ref: ref,
            mode: AudioMixerViewMode.vertical,
            isSelected: currentMode == AudioMixerViewMode.vertical,
            icon: Icons.view_week_rounded,
            tooltip: 'Vertical Channel Strips',
          ),
          _buildViewModeOption(
            ref: ref,
            mode: AudioMixerViewMode.horizontal,
            isSelected: currentMode == AudioMixerViewMode.horizontal,
            icon: Icons.table_rows_rounded,
            tooltip: 'Horizontal Channel Rows',
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeOption({
    required WidgetRef ref,
    required AudioMixerViewMode mode,
    required bool isSelected,
    required IconData icon,
    required String tooltip,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () {
            if (!isSelected) {
              Haptics.selection();
              ref.read(audioViewModeProvider.notifier).setMode(mode);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentCyan : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 13,
              color: isSelected
                  ? const Color(0xFF090A0E)
                  : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
