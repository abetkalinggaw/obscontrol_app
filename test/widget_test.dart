import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/macro_action.dart';
import 'package:obscontrol_app/models/obs_audio_source.dart';
import 'package:obscontrol_app/models/obs_scene.dart';
import 'package:obscontrol_app/models/obs_stats.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/ui/screens/main_navigation_screen.dart';
import 'package:obscontrol_app/ui/screens/connection_settings_screen.dart';
import 'package:obscontrol_app/ui/dialogs/quick_connect_sheet.dart';
import 'package:obscontrol_app/ui/dialogs/connection_guide_dialog.dart';
import 'package:obscontrol_app/ui/widgets/audio_channel_strip.dart';
import 'package:obscontrol_app/ui/widgets/liquid_glass_bottom_bar.dart';
import 'package:obscontrol_app/ui/widgets/macro_tile.dart';
import 'package:obscontrol_app/ui/widgets/scene_grid.dart';
import 'package:obscontrol_app/ui/widgets/scene_preview_box.dart';
import 'package:obscontrol_app/ui/widgets/telemetry_header.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _mockConnectedObs(ProviderContainer container) {
  final service = container.read(obsWebSocketServiceProvider);
  container
      .read(obsProvider.notifier)
      .setMockState(
        status: ObsConnectionStatus.connected,
        stats: const ObsStats(
          activeFps: 60.0,
          cpuUsage: 12.5,
          outputTotalFrames: 1000,
          outputSkippedFrames: 0,
          isStreaming: true,
          isRecording: true,
          studioModeEnabled: true,
        ),
      );
  service.onScenesUpdated?.call(
    const [
      ObsScene(name: 'Starting Soon', sceneIndex: 0),
      ObsScene(name: 'Live Camera (1080p)', sceneIndex: 1),
      ObsScene(name: 'Screen Share + Cam', sceneIndex: 2),
      ObsScene(name: 'BRB / Intermission', sceneIndex: 3),
    ],
    'Live Camera (1080p)',
    'Screen Share + Cam',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TelemetryHeader displays status, FPS, and triggers actions', (
    WidgetTester tester,
  ) async {
    var streamTapped = false;
    var recordTapped = false;
    var settingsTapped = false;
    var collapseTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TelemetryHeader(
            connectionStatus: ObsConnectionStatus.connected,
            stats: const ObsStats(
              activeFps: 60.0,
              isStreaming: true,
              streamTimecodeSeconds: 3661,
            ),
            onToggleCollapse: () => collapseTapped = true,
            onOpenSettings: () => settingsTapped = true,
            onToggleStream: () => streamTapped = true,
            onToggleRecord: () => recordTapped = true,
            onSaveReplay: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Status: CONNECTED'), findsOneWidget);
    expect(find.text('01:01:01'), findsOneWidget);
    expect(find.text('60.0 FPS'), findsOneWidget);

    await tester.tap(find.text('STREAMING'));
    expect(streamTapped, isTrue);

    await tester.tap(find.text('RECORD'));
    expect(recordTapped, isTrue);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    expect(collapseTapped, isTrue);

    await tester.tap(find.byTooltip('Status: CONNECTED'));
    expect(settingsTapped, isTrue);
  });

  testWidgets('SceneGrid displays scenes and triggers selection callback', (
    WidgetTester tester,
  ) async {
    String? selectedScene;
    final scenes = [
      const ObsScene(name: 'Gameplay 4K', sceneIndex: 0, isProgram: true),
      const ObsScene(name: 'Camera Main', sceneIndex: 1, isPreview: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SceneGrid(
            scenes: scenes,
            activeProgramScene: 'Gameplay 4K',
            activePreviewScene: '',
            studioModeEnabled: false,
            onSelectScene: (s) => selectedScene = s,
          ),
        ),
      ),
    );

    expect(find.text('Gameplay 4K'), findsOneWidget);
    expect(find.text('Camera Main'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);

    await tester.tap(find.text('Camera Main'));
    expect(selectedScene, 'Camera Main');
  });

  testWidgets(
    'AudioChannelStrip shows fader, mute button, and responds to mute tap',
    (WidgetTester tester) async {
      var muteToggled = false;
      const source = ObsAudioSource(
        name: 'Mic/Aux',
        volumeMul: 0.8,
        volumeDb: -3.5,
        muted: false,
        leftLevel: 0.6,
        rightLevel: 0.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AudioChannelStrip(
              source: source,
              onVolumeChanged: (_) {},
              onToggleMute: () => muteToggled = true,
            ),
          ),
        ),
      );

      expect(find.text('Mic/Aux'), findsOneWidget);
      expect(find.text('-3.5 dB'), findsOneWidget);

      // Mute button — volume_up when unmuted
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      expect(muteToggled, isTrue);
    },
  );

  testWidgets(
    'MacroTile renders title, subtitle, and triggers onTap and onLongPress',
    (WidgetTester tester) async {
      var tapped = false;
      var longPressed = false;
      const macro = MacroAction(
        id: 'm1',
        title: 'BRB BREAK',
        subtitle: 'Break Scene',
        iconName: 'pause',
        colorValue: 0xFFFF9500,
        type: MacroType.switchScene,
        target: 'BRB / Intermission',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MacroTile(
              macro: macro,
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('BRB BREAK'), findsOneWidget);
      expect(find.text('Break Scene'), findsOneWidget);

      await tester.tap(find.byType(MacroTile));
      expect(tapped, isTrue);

      await tester.longPress(find.byType(MacroTile));
      expect(longPressed, isTrue);
    },
  );

  testWidgets('MainNavigationScreen mounts and switches tabs', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MainNavigationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tabs: Switcher, Audio, Settings (Macros removed)
    expect(find.text('Switcher'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Macros'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);

    // Tap Audio tab
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('SAVED CONNECTION PROFILES'), findsOneWidget);
  });

  testWidgets('Top bar collapses on chevron tap and expands on chevron tap', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late final ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );

    _mockConnectedObs(container);
    await tester.pumpAndSettle();

    // In expanded state, broadcast action labels are visible
    expect(find.text('STREAMING'), findsOneWidget);

    // Tap chevron to collapse
    await tester.tap(find.byTooltip('Hide Broadcast Controls'));
    await tester.pumpAndSettle();

    final collapsedHeader = tester.widget<TelemetryHeader>(
      find.byType(TelemetryHeader),
    );
    expect(collapsedHeader.isCollapsed, isTrue);

    // Verify scrolling does NOT un-collapse the top bar (dont use scroll to hide)
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TelemetryHeader>(find.byType(TelemetryHeader)).isCollapsed,
      isTrue,
    );

    // Tap chevron to expand
    await tester.tap(find.byTooltip('Show Broadcast Controls'));
    await tester.pumpAndSettle();

    final expandedHeader = tester.widget<TelemetryHeader>(
      find.byType(TelemetryHeader),
    );
    expect(expandedHeader.isCollapsed, isFalse);
  });

  testWidgets('Landscape mode displays two-pane multiview without bottom nav', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    // Set surface size to tablet/landscape (1280 x 800)
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late final ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );

    // Trigger Demo Mode to populate live multiview
    _mockConnectedObs(container);
    await tester.pumpAndSettle();

    // Verify dedicated landscape broadcast console elements:
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('PROGRAM'), findsOneWidget);
    expect(find.byKey(const Key('transition_cut_button')), findsOneWidget);
    expect(find.byKey(const Key('transition_fade_button')), findsOneWidget);
    expect(find.text('300ms'), findsOneWidget);
    expect(find.text('SCENES'), findsOneWidget);

    // Bottom navigation bar is hidden in fullscreen landscape
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets(
    'Landscape mode adapts preview layout when studio mode is toggled on and off',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: const MainNavigationScreen(),
              );
            },
          ),
        ),
      );

      final service = container.read(obsWebSocketServiceProvider);
      container.read(obsProvider.notifier).setMockState(
        status: ObsConnectionStatus.connected,
        stats: const ObsStats(
          studioModeEnabled: false,
        ),
      );
      service.onScenesUpdated?.call(
        const [
          ObsScene(name: 'Gameplay 4K', sceneIndex: 0),
          ObsScene(name: 'Facecam Studio', sceneIndex: 1),
        ],
        'Gameplay 4K',
        'Facecam Studio',
      );
      await tester.pumpAndSettle();

      // Studio Mode OFF: Single PROGRAM monitor, no PREVIEW in header
      expect(find.text('PROGRAM'), findsOneWidget);
      expect(find.text('PREVIEW'), findsNothing);
      expect(find.byKey(const Key('transition_cut_button')), findsNothing);

      // Verify master preview box is PROGRAM only
      var boxes = tester.widgetList<ScenePreviewBox>(find.byType(ScenePreviewBox));
      expect(boxes.any((b) => b.isProgram && b.sceneName == 'Gameplay 4K'), isTrue);
      expect(boxes.any((b) => b.isPreview), isFalse);

      // Now toggle studio mode to ON
      container.read(obsProvider.notifier).setMockState(
        status: ObsConnectionStatus.connected,
        stats: const ObsStats(
          studioModeEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      // Studio Mode ON: Both PREVIEW and PROGRAM monitors visible with CUT & FADE
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('PROGRAM'), findsOneWidget);
      expect(find.byKey(const Key('transition_cut_button')), findsOneWidget);
      expect(find.byKey(const Key('transition_fade_button')), findsOneWidget);
      expect(find.text('300ms'), findsOneWidget);

      boxes = tester.widgetList<ScenePreviewBox>(find.byType(ScenePreviewBox));
      expect(boxes.any((b) => b.isPreview && b.sceneName == 'Facecam Studio'), isTrue);
      expect(boxes.any((b) => b.isProgram && b.sceneName == 'Gameplay 4K'), isTrue);
    },
  );

  testWidgets(
    'Landscape mode auto-hides bars on Switcher and toggles via floating pill',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: const MainNavigationScreen(),
              );
            },
          ),
        ),
      );

      _mockConnectedObs(container);
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const Key('landscape_controls_toggle'));

      // Verify icon-only controls toggle button is present for fullscreen landscape
      expect(toggleFinder, findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // Tap toggle button to reveal bars
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Verify button now shows fullscreen icon and LiquidGlassBottomBar is visible
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      expect(find.byType(LiquidGlassBottomBar), findsOneWidget);

      // Tap toggle button to hide bars again
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    },
  );

  testWidgets('Landscape mode keeps navigation bar on bottom for Audio tab', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late final ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.darkTheme,
              home: const MainNavigationScreen(),
            );
          },
        ),
      ),
    );

    _mockConnectedObs(container);
    await tester.pumpAndSettle();

    final toggleFinder = find.byKey(const Key('landscape_controls_toggle'));

    // Reveal bars and tap Audio tab
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    // On Audio tab in landscape, LiquidGlassBottomBar is visible at bottom
    expect(find.byType(LiquidGlassBottomBar), findsOneWidget);
    expect(toggleFinder, findsOneWidget);
    // Standard NavigationRail should not exist
    expect(find.byType(NavigationRail), findsNothing);

    // Verify toggle button also works on Audio tab to hide and reveal bars
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
  });

  testWidgets(
    'ConnectionSettingsScreen renders accordions, supports Add, Edit, Delete and Recent Devices',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ConnectionSettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Accordion headers are present
      expect(find.text('SAVED CONNECTION PROFILES'), findsOneWidget);
      expect(find.text('RECENT DEVICES'), findsOneWidget);

      // Initial default profile should be visible in expanded state
      expect(find.text('MAIN STUDIO PC'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);

      // Test Accordion collapse on Saved Profiles
      await tester.tap(find.text('SAVED CONNECTION PROFILES'));
      await tester.pumpAndSettle();
      // In collapsed state, the child is faded out
      expect(find.text('MAIN STUDIO PC'), findsNothing);

      // Re-expand Saved Profiles
      await tester.tap(find.text('SAVED CONNECTION PROFILES'));
      await tester.pumpAndSettle();
      expect(find.text('MAIN STUDIO PC'), findsOneWidget);

      // Test Add Profile Dialog
      await tester.tap(find.text('ADD CONNECTION PROFILE'));
      await tester.pumpAndSettle();
      expect(find.text('ADD CONNECTION PROFILE'), findsWidgets);

      // Enter name & host
      await tester.enterText(
        find.widgetWithText(TextField, 'Studio Secondary'),
        'Auxiliary Mac',
      );
      await tester.tap(find.text('SAVE PROFILE'));
      await tester.pumpAndSettle();

      // Verify new profile is now rendered
      expect(find.text('AUXILIARY MAC'), findsOneWidget);

      // Test Edit Profile Dialog on the first profile
      final editButtons = find.byTooltip('Edit Profile');
      expect(editButtons, findsWidgets);
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('EDIT CONNECTION PROFILE'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Main Studio PC'),
        'Primary Rig',
      );
      await tester.tap(find.text('UPDATE PROFILE'));
      await tester.pumpAndSettle();
      expect(find.text('PRIMARY RIG'), findsOneWidget);

      // Test Delete Profile Dialog
      final deleteButtons = find.byTooltip('Delete Profile');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('DELETE PROFILE'), findsOneWidget);
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      // Primary Rig was deleted, Auxiliary Mac remains
      expect(find.text('PRIMARY RIG'), findsNothing);
      expect(find.text('AUXILIARY MAC'), findsOneWidget);
    },
  );

  testWidgets(
    'Recent Devices accordion allows connecting, saving as profile, removing, and clearing',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: ConnectionSettingsScreen()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state is displayed initially
      expect(
        find.textContaining('No recent connection history'),
        findsOneWidget,
      );

      // Add a recent device via provider
      await container
          .read(settingsProvider.notifier)
          .addRecentDevice(
            ObsConnectionProfile(
              id: 'recent_192.168.1.88_4455',
              name: 'Live Stage Laptop',
              host: '192.168.1.88',
              port: 4455,
              password: '',
              lastUsed: DateTime.now(),
            ),
          );
      await tester.pumpAndSettle();

      // Verify recent device card is shown
      expect(find.text('LIVE STAGE LAPTOP'), findsOneWidget);
      expect(find.textContaining('192.168.1.88:4455'), findsOneWidget);
      expect(find.textContaining('Just now'), findsOneWidget);

      // Test Accordion collapse on Recent Devices
      await tester.tap(find.text('RECENT DEVICES'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE STAGE LAPTOP'), findsNothing);

      // Re-expand
      await tester.tap(find.text('RECENT DEVICES'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE STAGE LAPTOP'), findsOneWidget);

      // Test "Save as Profile" opens prefilled Add Profile dialog
      await tester.tap(find.byTooltip('Save as Profile'));
      await tester.pumpAndSettle();
      expect(find.text('ADD CONNECTION PROFILE'), findsWidgets);
      expect(
        find.widgetWithText(TextField, 'Live Stage Laptop'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, '192.168.1.88'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Test "Remove" individual recent device
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE STAGE LAPTOP'), findsNothing);
      expect(
        find.textContaining('No recent connection history'),
        findsOneWidget,
      );

      // Add two devices and test "CLEAR" button in header
      await container
          .read(settingsProvider.notifier)
          .addRecentDevice(
            ObsConnectionProfile(
              id: 'r1',
              name: 'Cam 1 NDI',
              host: '192.168.1.50',
              port: 4455,
              password: '',
              lastUsed: DateTime.now(),
            ),
          );
      await container
          .read(settingsProvider.notifier)
          .addRecentDevice(
            ObsConnectionProfile(
              id: 'r2',
              name: 'Cam 2 NDI',
              host: '192.168.1.51',
              port: 4455,
              password: '',
              lastUsed: DateTime.now(),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('CAM 1 NDI'), findsOneWidget);
      expect(find.text('CAM 2 NDI'), findsOneWidget);

      // Tap CLEAR RECENT DEVICES in list
      await tester.tap(find.text('CLEAR RECENT DEVICES'));
      await tester.pumpAndSettle();
      expect(find.text('CLEAR ALL'), findsOneWidget);
      await tester.tap(find.text('CLEAR ALL'));
      await tester.pumpAndSettle();

      expect(find.text('CAM 1 NDI'), findsNothing);
      expect(
        find.textContaining('No recent connection history'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'QuickConnectSheet text fields start empty and display placeholder hints',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => QuickConnectSheet.show(context),
                    child: const Text('OPEN QUICK CONNECT'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN QUICK CONNECT'));
      await tester.pumpAndSettle();

      // Verify all 3 TextFields (Host, Port, Password) start with empty text
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(textFields.length, 3);
      for (final tf in textFields) {
        expect(tf.controller?.text, isEmpty);
      }

      // Verify placeholder hint texts
      expect(textFields[0].decoration?.hintText, '192.168.1.100');
      expect(textFields[1].decoration?.hintText, '4455');
      expect(textFields[2].decoration?.hintText, 'WebSocket Password');

      // Switch to vMix tab
      await tester.tap(find.text('vMix'));
      await tester.pumpAndSettle();

      final vmixFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      // Port field should still be empty and display vMix default port placeholder 8088
      expect(vmixFields[1].controller?.text, isEmpty);
      expect(vmixFields[1].decoration?.hintText, '8088');
      expect(
        vmixFields[2].decoration?.hintText,
        'Leave blank if unauthenticated',
      );
    },
  );

  testWidgets(
    'ConnectionGuideDialog displays guide tabs, instructions, and handles tab switching',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ConnectionGuideDialog.show(context),
                  child: const Text('OPEN GUIDE'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open guide dialog
      await tester.tap(find.text('OPEN GUIDE'));
      await tester.pumpAndSettle();

      // Verify dialog header & initial OBS tab
      expect(find.text('HOW TO CONNECT'), findsOneWidget);
      expect(find.text('Built-in WebSocket v5'), findsOneWidget);
      expect(
        find.textContaining('Tools  >  WebSocket Server Settings'),
        findsOneWidget,
      );

      // Switch to Streamlabs tab
      await tester.tap(find.text('Streamlabs'));
      await tester.pumpAndSettle();
      expect(find.text('Streamlabs Remote Access'), findsOneWidget);

      // Switch to vMix tab
      await tester.tap(find.text('vMix'));
      await tester.pumpAndSettle();
      expect(find.text('vMix Web Controller (REST/XML API)'), findsOneWidget);
      expect(
        find.textContaining('Settings  >  Web Controller'),
        findsOneWidget,
      );

      // Switch to Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('Local Network Requirements'), findsOneWidget);
      expect(
        find.textContaining('Find your PC\'s Local IP Address'),
        findsOneWidget,
      );

      // Tap GOT IT to dismiss
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      expect(find.text('HOW TO CONNECT'), findsNothing);
    },
  );
}
