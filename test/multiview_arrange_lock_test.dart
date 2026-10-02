import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/models/obs_scene.dart';
import 'package:obscontrol_app/models/obs_stats.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/scenes_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/ui/screens/switcher_screen.dart';
import 'package:obscontrol_app/ui/widgets/scene_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multiview Arrange & Lock Tests', () {
    test('StorageService persists and restores scene order and lock state', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      expect(storage.getSceneOrder(), isEmpty);
      expect(storage.getMultiviewLocked(), isFalse);

      await storage.setSceneOrder(['Scene C', 'Scene A', 'Scene B']);
      await storage.setMultiviewLocked(true);

      expect(storage.getSceneOrder(), ['Scene C', 'Scene A', 'Scene B']);
      expect(storage.getMultiviewLocked(), isTrue);
    });

    test('ScenesNotifier applies custom scene order and updates persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      // Initialize scenesProvider to register onScenesUpdated callback
      container.read(scenesProvider);
      final broadcastService = container.read(broadcastServiceProvider);

      // Send initial scenes from OBS
      broadcastService.onScenesUpdated?.call(
        const [
          ObsScene(name: 'Scene 1', sceneIndex: 0),
          ObsScene(name: 'Scene 2', sceneIndex: 1),
          ObsScene(name: 'Scene 3', sceneIndex: 2),
        ],
        'Scene 1',
        'Scene 2',
      );

      var state = container.read(scenesProvider);
      expect(state.scenes.map((s) => s.name).toList(), ['Scene 1', 'Scene 2', 'Scene 3']);

      // Reorder scenes: move index 2 (Scene 3) to index 0
      container.read(scenesProvider.notifier).reorderScenes(2, 0);

      state = container.read(scenesProvider);
      expect(state.scenes.map((s) => s.name).toList(), ['Scene 3', 'Scene 1', 'Scene 2']);
      expect(storage.getSceneOrder(), ['Scene 3', 'Scene 1', 'Scene 2']);

      // Lock multiview
      container.read(scenesProvider.notifier).toggleMultiviewLock();
      state = container.read(scenesProvider);
      expect(state.isLocked, isTrue);
      expect(storage.getMultiviewLocked(), isTrue);

      // While locked, reordering should be blocked
      container.read(scenesProvider.notifier).reorderScenes(0, 2);
      state = container.read(scenesProvider);
      expect(state.scenes.map((s) => s.name).toList(), ['Scene 3', 'Scene 1', 'Scene 2']);
    });

    testWidgets('SceneGrid renders lock button and toggles lock state', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      container.read(obsProvider.notifier).setMockState(
            status: ObsConnectionStatus.connected,
            stats: const ObsStats(
              studioModeEnabled: false,
              currentProgramScene: 'Scene 1',
            ),
          );

      final obsService = container.read(obsWebSocketServiceProvider);
      obsService.onScenesUpdated?.call(
        const [
          ObsScene(name: 'Scene 1', sceneIndex: 0),
          ObsScene(name: 'Scene 2', sceneIndex: 1),
        ],
        'Scene 1',
        '',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SwitcherScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lock button should be visible (initially unlocked)
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      expect(container.read(scenesProvider).isLocked, isFalse);

      // Tap lock button to lock multiview
      await tester.tap(find.byIcon(Icons.lock_open_rounded));
      await tester.pumpAndSettle();

      expect(container.read(scenesProvider).isLocked, isTrue);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('SCENES (LOCKED)'), findsOneWidget);

      // Tap lock button again to unlock
      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pumpAndSettle();

      expect(container.read(scenesProvider).isLocked, isFalse);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      expect(find.text('SCENES'), findsOneWidget);
    });

    testWidgets('SceneGrid in locked mode allows selecting scene but disables layout arrangement', (WidgetTester tester) async {
      var selected = '';
      const scenes = [
        ObsScene(name: 'Cam 1', sceneIndex: 0),
        ObsScene(name: 'Cam 2', sceneIndex: 1),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SceneGrid(
              scenes: scenes,
              activeProgramScene: 'Cam 1',
              activePreviewScene: '',
              studioModeEnabled: false,
              isLocked: true,
              onSelectScene: (name) => selected = name,
              onReorderScene: (from, to) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Cam 2 while locked - should successfully select scene
      await tester.tap(find.text('Cam 2'));
      await tester.pumpAndSettle();

      expect(selected, 'Cam 2');

      // Drag handles should NOT be rendered when locked
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      // DragTargets should NOT be rendered when locked
      expect(find.byType(DragTarget<int>), findsNothing);
    });
  });
}
