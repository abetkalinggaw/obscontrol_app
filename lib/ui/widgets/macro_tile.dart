import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/macro_action.dart';

/// Flat Industrial Macro Pad.
///
/// Designed as a tactile broadcast deck key with clean flat geometry,
/// high-contrast functional color framing, and bold uppercase labeling.
class MacroTile extends StatelessWidget {
  final MacroAction macro;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MacroTile({
    super.key,
    required this.macro,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'pause':
        return Icons.pause_rounded;
      case 'mic_off':
        return Icons.mic_off_rounded;
      case 'volume_off':
        return Icons.volume_off_rounded;
      case 'cut':
        return Icons.content_cut_rounded;
      case 'videogame_asset':
        return Icons.sports_esports_rounded;
      case 'videocam':
        return Icons.videocam_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'history':
        return Icons.history_rounded;
      case 'screen_share':
        return Icons.screen_share_rounded;
      case 'music_off':
        return Icons.music_off_rounded;
      case 'fiber_manual_record':
        return Icons.fiber_manual_record_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'camera':
        return Icons.camera_alt_rounded;
      case 'play':
        return Icons.play_arrow_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(macro.colorValue);
    final iconData = _resolveIcon(macro.iconName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Haptics.medium();
          onTap();
        },
        onLongPress: () {
          Haptics.heavy();
          onLongPress();
        },
        borderRadius: BorderRadius.circular(5),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.50),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Geometric Icon Container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: accentColor,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  iconData,
                  color: accentColor,
                  size: 20,
                ),
              ),

              const SizedBox(height: 8),

              // Title (Bold Geometric Styling)
              Text(
                macro.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 2),

              // Subtitle
              Text(
                macro.subtitle.isNotEmpty ? macro.subtitle : macro.type.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
