import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/macro_action.dart';
import '../../providers/audio_provider.dart';
import '../../providers/macro_provider.dart';
import '../../providers/scenes_provider.dart';
import '../dialogs/edit_macro_dialog.dart';
import '../widgets/floating_bars_insets.dart';
import '../widgets/macro_tile.dart';

class MacroDeckScreen extends ConsumerWidget {
  const MacroDeckScreen({super.key});

  void _openEditDialog(BuildContext context, WidgetRef ref, MacroAction macro) {
    final scenes = ref.read(scenesProvider).scenes.map((s) => s.name).toList();
    final audios = ref.read(audioProvider).sources.map((s) => s.name).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditMacroDialog(
        macro: macro,
        availableScenes: scenes.isNotEmpty
            ? scenes
            : ['Gameplay 4K', 'Camera Main', 'BRB / Intermission', 'Screen Share', 'Ending Credits'],
        availableAudioSources: audios.isNotEmpty
            ? audios
            : ['Mic/Aux', 'Desktop Audio', 'Spotify BGM', 'Discord Call'],
        onSave: (updated) {
          ref.read(macroProvider.notifier).updateMacro(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insets = FloatingBarsInsets.of(context);
    final macros = ref.watch(macroProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(12, insets.topInset, 12, insets.bottomInset),
      children: [
        // Sub-header with Title & Deck Reset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 16, color: AppColors.accentCyan),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'STREAM MACRO DECK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Long-press to edit',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Haptics.light();
                      ref.read(macroProvider.notifier).resetToDefault();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Macro deck reset to default presets'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 20, color: AppColors.textSecondary),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    padding: EdgeInsets.zero,
                    tooltip: 'Reset Macro Deck to Defaults',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Strict 3x4 Grid (12 chunky buttons)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: macros.length.clamp(0, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final macro = macros[index];
            return MacroTile(
              macro: macro,
              onTap: () {
                ref.read(macroProvider.notifier).executeMacro(macro);
              },
              onLongPress: () {
                _openEditDialog(context, ref, macro);
              },
            );
          },
        ),
      ],
    );
  }
}
