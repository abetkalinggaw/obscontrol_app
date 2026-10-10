import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../models/macro_action.dart';

class EditMacroDialog extends StatefulWidget {
  final MacroAction macro;
  final List<String> availableScenes;
  final List<String> availableAudioSources;
  final ValueChanged<MacroAction> onSave;

  const EditMacroDialog({
    super.key,
    required this.macro,
    required this.availableScenes,
    required this.availableAudioSources,
    required this.onSave,
  });

  @override
  State<EditMacroDialog> createState() => _EditMacroDialogState();
}

class _EditMacroDialogState extends State<EditMacroDialog> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late MacroType _selectedType;
  late String _selectedTarget;
  late String _selectedIcon;
  late int _selectedColor;

  final List<String> _icons = [
    'bolt',
    'pause',
    'mic_off',
    'volume_off',
    'cut',
    'videogame_asset',
    'videocam',
    'auto_awesome',
    'history',
    'screen_share',
    'music_off',
    'fiber_manual_record',
    'flag',
    'camera',
    'play',
  ];

  final List<int> _colors = [
    0xFFFF3B30, // Red
    0xFFFF9500, // Orange
    0xFFFFCC00, // Amber
    0xFF34C759, // Mint
    0xFF00C7FF, // Cyan
    0xFF007AFF, // Blue
    0xFFAF52DE, // Purple
    0xFFFF2D55, // Pink
    0xFF8E8E93, // Grey
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.macro.title);
    _subtitleController = TextEditingController(text: widget.macro.subtitle);
    _selectedType = widget.macro.type;
    _selectedTarget = widget.macro.target;
    _selectedIcon = widget.macro.iconName;
    _selectedColor = widget.macro.colorValue;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

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
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          top: BorderSide(
            color: AppColors.surfaceBorderActive,
            width: 1.0,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Customize Macro Tile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title & Subtitle inputs
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Button Label',
                hintText: 'e.g. BRB + MUTE',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Subtitle (Optional)',
                hintText: 'e.g. Break Scene',
              ),
            ),
            const SizedBox(height: 16),

            // Action Type Dropdown
            const Text(
              'Action Type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MacroType>(
                  value: _selectedType,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  items: MacroType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                        // Pre-populate target
                        if (val == MacroType.switchScene && widget.availableScenes.isNotEmpty) {
                          _selectedTarget = widget.availableScenes.first;
                        } else if (val == MacroType.toggleMute && widget.availableAudioSources.isNotEmpty) {
                          _selectedTarget = widget.availableAudioSources.first;
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Target (Scene or Audio Source)
            if (_selectedType == MacroType.switchScene && widget.availableScenes.isNotEmpty) ...[
              const Text(
                'Target Scene',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.availableScenes.contains(_selectedTarget)
                        ? _selectedTarget
                        : widget.availableScenes.first,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceElevated,
                    items: widget.availableScenes.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTarget = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else if (_selectedType == MacroType.toggleMute && widget.availableAudioSources.isNotEmpty) ...[
              const Text(
                'Target Audio Source',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.availableAudioSources.contains(_selectedTarget)
                        ? _selectedTarget
                        : widget.availableAudioSources.first,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceElevated,
                    items: widget.availableAudioSources.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTarget = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Icon Picker
            const Text(
              'Select Icon',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((iconName) {
                final isSelected = _selectedIcon == iconName;
                return InkWell(
                  onTap: () {
                    Haptics.selection();
                    setState(() => _selectedIcon = iconName);
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? Color(_selectedColor).withValues(alpha: 0.20) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected ? Color(_selectedColor) : AppColors.surfaceBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Icon(
                      _resolveIcon(iconName),
                      color: isSelected ? Color(_selectedColor) : AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color Accent Picker
            const Text(
              'Accent Color',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((c) {
                final isSelected = _selectedColor == c;
                return InkWell(
                  onTap: () {
                    Haptics.selection();
                    setState(() => _selectedColor = c);
                  },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected ? Colors.white : AppColors.surfaceBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Haptics.medium();
                  final updated = widget.macro.copyWith(
                    title: _titleController.text.trim().isEmpty ? 'Macro' : _titleController.text.trim(),
                    subtitle: _subtitleController.text.trim(),
                    type: _selectedType,
                    target: _selectedTarget,
                    iconName: _selectedIcon,
                    colorValue: _selectedColor,
                  );
                  widget.onSave(updated);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
