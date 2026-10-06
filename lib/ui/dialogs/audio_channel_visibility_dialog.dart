import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../providers/audio_provider.dart';

/// Modal sheet for selecting which audio channels to show or hide on the audio mixer.
class AudioChannelVisibilitySheet extends ConsumerWidget {
  const AudioChannelVisibilitySheet({super.key});

  static Future<void> show(BuildContext context) {
    Haptics.selection();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AudioChannelVisibilitySheet(),
    );
  }

  IconData _getSourceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('mic') || lower.contains('aux')) return Icons.mic_none_rounded;
    if (lower.contains('spotify') || lower.contains('music') || lower.contains('bgm')) return Icons.music_note_rounded;
    if (lower.contains('discord') || lower.contains('call') || lower.contains('chat')) return Icons.headset_rounded;
    if (lower.contains('game')) return Icons.sports_esports_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final hiddenChannels = ref.watch(hiddenAudioChannelsProvider);
    final allSources = audioState.sources;
    final visibleCount = allSources.where((s) => !hiddenChannels.contains(s.name)).length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.surfaceBorderActive,
          width: 1.0,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag Handle ─────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorderActive,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),

              // ── Header Row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 10, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AUDIO CHANNEL VISIBILITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Subtitle & Controls ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$visibleCount of ${allSources.length} visible',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuickActionButton(
                          label: 'SHOW ALL',
                          onTap: () {
                            Haptics.selection();
                            ref.read(hiddenAudioChannelsProvider.notifier).showAll();
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildQuickActionButton(
                          label: 'HIDE ALL',
                          onTap: () {
                            Haptics.selection();
                            ref
                                .read(hiddenAudioChannelsProvider.notifier)
                                .hideAll(allSources.map((s) => s.name).toList());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.surfaceBorder),

              // ── Channels List ───────────────────────────────────────
              Flexible(
                child: allSources.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28.0),
                        child: Text(
                          'No audio channels detected from OBS.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: allSources.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final source = allSources[index];
                          final isVisible = !hiddenChannels.contains(source.name);
                          final icon = _getSourceIcon(source.name);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Haptics.selection();
                                ref
                                    .read(hiddenAudioChannelsProvider.notifier)
                                    .toggleChannel(source.name);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isVisible
                                      ? AppColors.surface
                                      : AppColors.surfaceElevated.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isVisible
                                        ? AppColors.surfaceBorder
                                        : AppColors.surfaceBorder.withValues(alpha: 0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Custom Flat Checkbox
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isVisible
                                            ? AppColors.accentCyan
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: isVisible
                                              ? AppColors.accentCyan
                                              : AppColors.textMuted,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: isVisible
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 13,
                                              color: AppColors.background,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),

                                    // Channel Icon
                                    Icon(
                                      icon,
                                      size: 15,
                                      color: isVisible
                                          ? AppColors.accentCyan
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),

                                    // Channel Name
                                    Expanded(
                                      child: Text(
                                        source.name,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: isVisible
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: source.muted
                                            ? AppColors.liveRed.withValues(alpha: 0.15)
                                            : AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        source.muted ? 'MUTED' : 'ACTIVE',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: source.muted
                                              ? AppColors.liveRed
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 1, color: AppColors.surfaceBorder),

              // ── Done Button ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton(
                    onPressed: () {
                      Haptics.selection();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.accentCyan,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
