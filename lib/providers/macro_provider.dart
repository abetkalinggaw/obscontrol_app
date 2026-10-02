import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/obs_websocket_service.dart';
import '../core/services/storage_service.dart';
import '../core/utils/haptics.dart';
import '../models/macro_action.dart';
import 'obs_provider.dart';
import 'settings_provider.dart';

class MacroNotifier extends Notifier<List<MacroAction>> {
  StorageService get _storage => ref.read(storageServiceProvider);
  ObsWebSocketService get _obs => ref.read(obsWebSocketServiceProvider);

  @override
  List<MacroAction> build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.loadMacros();
  }

  Future<void> executeMacro(MacroAction macro) async {
    Haptics.medium();

    switch (macro.type) {
      case MacroType.switchScene:
        if (macro.target.isNotEmpty) {
          await _obs.setCurrentProgramScene(macro.target);
        }
        break;
      case MacroType.toggleMute:
        if (macro.target.isNotEmpty) {
          await _obs.toggleInputMute(macro.target);
        }
        break;
      case MacroType.toggleStream:
        await _obs.toggleStream();
        break;
      case MacroType.toggleRecord:
        await _obs.toggleRecord();
        break;
      case MacroType.saveReplay:
        await _obs.saveReplayBuffer();
        break;
      case MacroType.studioTransition:
        await _obs.triggerStudioTransition(macro.target.isNotEmpty ? macro.target : 'Cut');
        break;
      case MacroType.toggleSourceVisibility:
        break;
      case MacroType.screenshot:
        break;
    }
  }

  Future<void> updateMacro(MacroAction updated) async {
    final list = List<MacroAction>.from(state);
    final idx = list.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.add(updated);
    }
    await _storage.saveMacros(list);
    state = list;
  }

  Future<void> resetToDefault() async {
    final def = [
      const MacroAction(
        id: 'm1',
        title: 'BRB + MUTE',
        subtitle: 'Break Scene',
        iconName: 'pause',
        colorValue: 0xFFFF9500,
        type: MacroType.switchScene,
        target: 'BRB / Intermission',
      ),
      const MacroAction(
        id: 'm2',
        title: 'MIC MUTE',
        subtitle: 'Toggle Mic',
        iconName: 'mic_off',
        colorValue: 0xFFFF3B30,
        type: MacroType.toggleMute,
        target: 'Mic/Aux',
      ),
      const MacroAction(
        id: 'm3',
        title: 'DESKTOP MUTE',
        subtitle: 'All Audio',
        iconName: 'volume_off',
        colorValue: 0xFF5856D6,
        type: MacroType.toggleMute,
        target: 'Desktop Audio',
      ),
      const MacroAction(
        id: 'm4',
        title: 'CUT TRANS',
        subtitle: 'Studio Cut',
        iconName: 'cut',
        colorValue: 0xFF34C759,
        type: MacroType.studioTransition,
        target: 'Cut',
      ),
      const MacroAction(
        id: 'm5',
        title: 'GAMEPLAY',
        subtitle: 'Main Scene',
        iconName: 'videogame_asset',
        colorValue: 0xFF007AFF,
        type: MacroType.switchScene,
        target: 'Gameplay 4K',
      ),
      const MacroAction(
        id: 'm6',
        title: 'FULL CAM',
        subtitle: 'Face Cam',
        iconName: 'videocam',
        colorValue: 0xFFAF52DE,
        type: MacroType.switchScene,
        target: 'Camera Main',
      ),
      const MacroAction(
        id: 'm7',
        title: 'FADE TRANS',
        subtitle: 'Smooth Fade',
        iconName: 'auto_awesome',
        colorValue: 0xFFFFCC00,
        type: MacroType.studioTransition,
        target: 'Fade',
      ),
      const MacroAction(
        id: 'm8',
        title: 'REPLAY CLIP',
        subtitle: 'Save Buffer',
        iconName: 'history',
        colorValue: 0xFFFF2D55,
        type: MacroType.saveReplay,
        target: '',
      ),
      const MacroAction(
        id: 'm9',
        title: 'SCREEN SHARE',
        subtitle: 'Desktop Display',
        iconName: 'screen_share',
        colorValue: 0xFF5AC8FA,
        type: MacroType.switchScene,
        target: 'Screen Share',
      ),
      const MacroAction(
        id: 'm10',
        title: 'BGM MUTE',
        subtitle: 'Spotify / Music',
        iconName: 'music_off',
        colorValue: 0xFF32D74B,
        type: MacroType.toggleMute,
        target: 'Spotify BGM',
      ),
      const MacroAction(
        id: 'm11',
        title: 'START REC',
        subtitle: 'Local Record',
        iconName: 'fiber_manual_record',
        colorValue: 0xFFFF3B30,
        type: MacroType.toggleRecord,
        target: '',
      ),
      const MacroAction(
        id: 'm12',
        title: 'OUTRO SCENE',
        subtitle: 'Stream Ending',
        iconName: 'flag',
        colorValue: 0xFF8E8E93,
        type: MacroType.switchScene,
        target: 'Ending Credits',
      ),
    ];
    await _storage.saveMacros(def);
    state = def;
  }
}

final macroProvider = NotifierProvider<MacroNotifier, List<MacroAction>>(MacroNotifier.new);
