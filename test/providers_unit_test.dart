import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/models/obs_audio_source.dart';
import 'package:obscontrol_app/models/obs_scene.dart';
import 'package:obscontrol_app/providers/audio_provider.dart';
import 'package:obscontrol_app/providers/macro_provider.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/scenes_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/providers/transition_mix_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });

  group('TransitionMixNotifier Unit Tests', () {
    test('initial state has 0.0 progress and generation 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mix = container.read(transitionMixProvider);
      expect(mix.progress, 0.0);
      expect(mix.generation, 0);
      expect(mix.active, isFalse);
    });

    test('setManual updates progress, clamps between 0.0 and 1.0, and increments generation when starting', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(transitionMixProvider.notifier);

      // Start transition: from 0.0 to 0.5 -> generation increments from 0 to 1
      notifier.setManual(0.5);
      var state = container.read(transitionMixProvider);
      expect(state.progress, 0.5);
      expect(state.generation, 1);
      expect(state.active, isTrue);

      // In progress move: generation should stay the same
      notifier.setManual(0.8);
      state = container.read(transitionMixProvider);
      expect(state.progress, 0.8);
      expect(state.generation, 1);

      // Clamping test: > 1.0 clamps to 1.0
      notifier.setManual(1.5);
      state = container.read(transitionMixProvider);
      expect(state.progress, 1.0);

      // Clamping test: < 0.0 clamps to 0.0
      notifier.setManual(-0.2);
      state = container.read(transitionMixProvider);
      expect(state.progress, 0.0);
      expect(state.active, isFalse);
    });

    test('reset clears progress back to 0.0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(transitionMixProvider.notifier);
      notifier.setManual(0.6);
      expect(container.read(transitionMixProvider).active, isTrue);

      notifier.reset();
      final state = container.read(transitionMixProvider);
      expect(state.progress, 0.0);
      expect(state.active, isFalse);
    });
  });

  group('Audio Providers Unit Tests', () {
    test('AudioViewModeNotifier toggles and persists between vertical and horizontal', () {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(audioViewModeProvider.notifier);
      expect(
        container.read(audioViewModeProvider),
        AudioMixerViewMode.vertical,
      );

      notifier.toggle();
      expect(
        container.read(audioViewModeProvider),
        AudioMixerViewMode.horizontal,
      );
      expect(storage.getAudioMixerViewMode(), 'horizontal');

      notifier.setMode(AudioMixerViewMode.vertical);
      expect(
        container.read(audioViewModeProvider),
        AudioMixerViewMode.vertical,
      );
      expect(storage.getAudioMixerViewMode(), 'vertical');
    });

    test('HiddenAudioChannelsNotifier toggles, shows all, and hides all', () {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(hiddenAudioChannelsProvider.notifier);
      expect(container.read(hiddenAudioChannelsProvider), isEmpty);

      notifier.toggleChannel('Mic/Aux');
      expect(
        container.read(hiddenAudioChannelsProvider).contains('Mic/Aux'),
        isTrue,
      );
      expect(storage.getHiddenAudioChannels(), contains('Mic/Aux'));

      notifier.toggleChannel('Mic/Aux');
      expect(
        container.read(hiddenAudioChannelsProvider).contains('Mic/Aux'),
        isFalse,
      );

      notifier.hideAll(['Mic/Aux', 'Desktop Audio', 'Discord']);
      expect(container.read(hiddenAudioChannelsProvider).length, 3);

      notifier.showAll();
      expect(container.read(hiddenAudioChannelsProvider), isEmpty);
      expect(storage.getHiddenAudioChannels(), isEmpty);
    });

    test(
      'MonitoredAudioChannelNotifier selects channel and updates storage',
      () {
        final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(monitoredAudioChannelProvider.notifier);
        expect(container.read(monitoredAudioChannelProvider), isNull);

        notifier.selectChannel('Desktop Audio');
        expect(container.read(monitoredAudioChannelProvider), 'Desktop Audio');
        expect(storage.getMonitoredAudioChannel(), 'Desktop Audio');
      },
    );

    test('AudioNotifier handles broadcast audio source callbacks', () {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final obsService = container.read(obsWebSocketServiceProvider);
      // Trigger initial read
      container.read(audioProvider);

      obsService.onAudioSourcesUpdated?.call([
        const ObsAudioSource(name: 'Mic 1', volumeMul: 0.8),
        const ObsAudioSource(name: 'Spotify', volumeMul: 0.5),
      ]);

      final state = container.read(audioProvider);
      expect(state.sources.length, 2);
      expect(state.sources[0].name, 'Mic 1');
      expect(state.sources[1].name, 'Spotify');
    });
  });

  group('ScenesProvider & GridCountProvider Unit Tests', () {
    test('GridCountNotifier switches between 4 and 8 only', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gridCountProvider.notifier);
      expect(container.read(gridCountProvider), 8);

      notifier.setCount(4);
      expect(container.read(gridCountProvider), 4);

      // Attempt invalid count
      notifier.setCount(16);
      expect(container.read(gridCountProvider), 4); // unchanged
    });

    test(
      'TransitionDurationNotifier updates duration and saves to storage',
      () async {
        final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(transitionDurationProvider.notifier);
        expect(container.read(transitionDurationProvider), 300);

        await notifier.setDuration(500);
        expect(container.read(transitionDurationProvider), 500);
        expect(storage.getTransitionDuration(), 500);
      },
    );

    test('ScenesNotifier reorders scenes and persists order', () {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final obsService = container.read(obsWebSocketServiceProvider);
      container.read(scenesProvider);

      obsService.onScenesUpdated?.call(
        [
          const ObsScene(name: 'Scene A', sceneIndex: 0),
          const ObsScene(name: 'Scene B', sceneIndex: 1),
          const ObsScene(name: 'Scene C', sceneIndex: 2),
        ],
        'Scene A',
        'Scene B',
      );

      var state = container.read(scenesProvider);
      expect(state.scenes.map((s) => s.name).toList(), [
        'Scene A',
        'Scene B',
        'Scene C',
      ]);

      final notifier = container.read(scenesProvider.notifier);
      notifier.reorderScenes(0, 2);

      state = container.read(scenesProvider);
      expect(state.scenes.map((s) => s.name).toList(), [
        'Scene B',
        'Scene C',
        'Scene A',
      ]);
      expect(storage.getSceneOrder(), ['Scene B', 'Scene C', 'Scene A']);
    });

    test('ScenesNotifier arrangement selection and swap', () {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final obsService = container.read(obsWebSocketServiceProvider);
      container.read(scenesProvider);

      obsService.onScenesUpdated?.call(
        [
          const ObsScene(name: 'Scene 1', sceneIndex: 0),
          const ObsScene(name: 'Scene 2', sceneIndex: 1),
        ],
        'Scene 1',
        'Scene 2',
      );

      final notifier = container.read(scenesProvider.notifier);
      notifier.selectSceneForArrangement('Scene 1');
      expect(container.read(scenesProvider).selectedSceneName, 'Scene 1');

      // Tapping same scene again unselects it
      notifier.selectSceneForArrangement('Scene 1');
      expect(container.read(scenesProvider).selectedSceneName, isNull);

      // Select and swap
      notifier.selectSceneForArrangement('Scene 1');
      notifier.swapSelectedSceneWith(1);
      final state = container.read(scenesProvider);
      expect(state.scenes[0].name, 'Scene 2');
      expect(state.scenes[1].name, 'Scene 1');
      expect(state.selectedSceneName, isNull);
    });
  });

  group('MacroProvider Unit Tests', () {
    test('loads initial macros and allows updating and resetting', () async {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final macros = container.read(macroProvider);
      expect(macros, isNotEmpty);

      final notifier = container.read(macroProvider.notifier);
      final updatedMacro = macros.first.copyWith(title: 'NEW TITLE');
      await notifier.updateMacro(updatedMacro);

      expect(container.read(macroProvider).first.title, 'NEW TITLE');

      await notifier.resetToDefault();
      expect(container.read(macroProvider).first.title, 'BRB + MUTE');
    });

    test('executeMacro executes supported actions without error', () async {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(macroProvider.notifier);
      final macro = container.read(macroProvider).first;

      // Executing macro should complete safely
      await expectLater(notifier.executeMacro(macro), completes);
    });
  });

  group('ObsConnectionState & SettingsProvider Unit Tests', () {
    test('ObsConnectionState copyWith updates fields properly', () {
      const state = ObsConnectionState();
      final updated = state.copyWith(
        status: ObsConnectionStatus.connected,
        currentHost: '192.168.1.55',
        currentPort: 4455,
        currentSoftware: StreamingSoftware.obsStudio,
      );

      expect(updated.status, ObsConnectionStatus.connected);
      expect(updated.currentHost, '192.168.1.55');
      expect(updated.currentPort, 4455);
      expect(updated.currentSoftware, StreamingSoftware.obsStudio);
    });

    test(
      'SettingsNotifier toggles haptics, auto-reconnect, and screen wake lock',
      () async {
        final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(settingsProvider.notifier);

        await notifier.setHapticsEnabled(false);
        expect(container.read(settingsProvider).hapticsEnabled, isFalse);
        expect(storage.getHapticsEnabled(), isFalse);

        await notifier.setAutoReconnect(false);
        expect(container.read(settingsProvider).autoReconnect, isFalse);
        expect(storage.getAutoReconnect(), isFalse);

        await notifier.setKeepScreenOn(true);
        expect(container.read(settingsProvider).keepScreenOn, isTrue);
        expect(storage.getKeepScreenOn(), isTrue);
      },
    );
  });
}
