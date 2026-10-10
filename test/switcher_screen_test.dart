import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/models/obs_scene.dart';
import 'package:obscontrol_app/models/obs_stats.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/ui/screens/switcher_screen.dart';
import 'package:obscontrol_app/ui/widgets/grid_count_selector.dart';
import 'package:obscontrol_app/ui/widgets/obs_disconnected_prompt.dart';
import 'package:obscontrol_app/ui/widgets/scene_grid.dart';
import 'package:obscontrol_app/ui/widgets/studio_transition_control.dart';
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

  group('SwitcherScreen Widget Tests', () {
    testWidgets('renders ObsDisconnectedPrompt when OBS is disconnected', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: SwitcherScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ObsDisconnectedPrompt), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);
      expect(find.text('CONNECT CONTROLLER'), findsOneWidget);
    });

    testWidgets(
      'renders Program Monitor and Scene Grid when connected in standard mode',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: const Scaffold(body: SwitcherScreen()),
                );
              },
            ),
          ),
        );

        // Connect mock OBS
        final obsNotifier = container.read(obsProvider.notifier);
        obsNotifier.setMockState(
          status: ObsConnectionStatus.connected,
          stats: const ObsStats(
            studioModeEnabled: false,
            currentProgramScene: 'Main Camera',
          ),
        );

        final service = container.read(obsWebSocketServiceProvider);
        service.onScenesUpdated?.call(
          const [
            ObsScene(name: 'Main Camera', sceneIndex: 0),
            ObsScene(name: 'Screen Share', sceneIndex: 1),
            ObsScene(name: 'Be Right Back', sceneIndex: 2),
            ObsScene(name: 'Ending Credits', sceneIndex: 3),
          ],
          'Main Camera',
          '',
        );

        await tester.pumpAndSettle();

        // Header shows PROGRAM and active scene
        expect(find.text('PROGRAM'), findsOneWidget);
        expect(find.text('Main Camera'), findsWidgets);

        // SceneGrid and scenes are rendered
        expect(find.byType(SceneGrid), findsOneWidget);
        expect(find.text('Screen Share'), findsOneWidget);
        expect(find.text('Be Right Back'), findsOneWidget);
        expect(find.text('Ending Credits'), findsOneWidget);

        // 4/8 Grid Count Selector is present
        expect(find.byType(GridCountSelector), findsOneWidget);
      },
    );

    testWidgets(
      'renders dual PRV/PGM monitors and StudioTransitionControl when Studio Mode is active',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: const Scaffold(body: SwitcherScreen()),
                );
              },
            ),
          ),
        );

        final obsNotifier = container.read(obsProvider.notifier);
        obsNotifier.setMockState(
          status: ObsConnectionStatus.connected,
          stats: const ObsStats(
            studioModeEnabled: true,
            currentProgramScene: 'Program Scene',
            currentPreviewScene: 'Preview Scene',
          ),
        );

        final service = container.read(obsWebSocketServiceProvider);
        service.onScenesUpdated?.call(
          const [
            ObsScene(name: 'Preview Scene', sceneIndex: 0),
            ObsScene(name: 'Program Scene', sceneIndex: 1),
          ],
          'Program Scene',
          'Preview Scene',
        );

        await tester.pumpAndSettle();

        // In studio mode, header has PRV and PGM indicators
        expect(find.text('PRV'), findsOneWidget);
        expect(find.text('PGM'), findsOneWidget);
        expect(find.text('Preview Scene'), findsWidgets);
        expect(find.text('Program Scene'), findsWidgets);

        // Studio transition controls (CUT / FADE / T-Bar) are visible
        expect(find.byType(StudioTransitionControl), findsOneWidget);
        expect(find.byKey(const Key('transition_cut_button')), findsOneWidget);
        expect(find.byKey(const Key('transition_fade_button')), findsOneWidget);
      },
    );
  });
}
