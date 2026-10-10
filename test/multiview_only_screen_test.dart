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
import 'package:obscontrol_app/ui/screens/multiview_only_screen.dart';
import 'package:obscontrol_app/ui/widgets/grid_count_selector.dart';
import 'package:obscontrol_app/ui/widgets/obs_disconnected_prompt.dart';
import 'package:obscontrol_app/ui/widgets/scene_grid.dart';
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

  group('MultiviewOnlyScreen Widget Tests', () {
    testWidgets('renders Multiview Offline prompt when not connected', (
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
            home: const Scaffold(body: MultiviewOnlyScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ObsDisconnectedPrompt), findsOneWidget);
      expect(find.text('Multiview Offline'), findsOneWidget);
    });

    testWidgets(
      'renders non-interactive multiview monitors and scene feeds in connected state',
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
                  home: const Scaffold(body: MultiviewOnlyScreen()),
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
            currentProgramScene: 'PGM Feed',
            currentPreviewScene: 'PRV Feed',
          ),
        );

        final service = container.read(obsWebSocketServiceProvider);
        service.onScenesUpdated?.call(
          const [
            ObsScene(name: 'PRV Feed', sceneIndex: 0),
            ObsScene(name: 'PGM Feed', sceneIndex: 1),
            ObsScene(name: 'Cam 3', sceneIndex: 2),
            ObsScene(name: 'Graphics', sceneIndex: 3),
          ],
          'PGM Feed',
          'PRV Feed',
        );

        await tester.pumpAndSettle();

        // Header shows PRV and PGM indicators
        expect(find.text('PRV'), findsOneWidget);
        expect(find.text('PGM'), findsOneWidget);
        expect(find.text('PRV Feed'), findsWidgets);
        expect(find.text('PGM Feed'), findsWidgets);

        // Grid displays scene feeds
        expect(find.byType(SceneGrid), findsOneWidget);
        expect(find.text('Cam 3'), findsOneWidget);
        expect(find.text('Graphics'), findsOneWidget);
        expect(find.byType(GridCountSelector), findsOneWidget);
      },
    );
  });
}
