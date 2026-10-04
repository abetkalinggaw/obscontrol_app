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
import 'package:obscontrol_app/ui/screens/landscape_multiview_screen.dart';
import 'package:obscontrol_app/ui/widgets/scene_preview_box.dart';
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

  testWidgets('StudioTransitionControl renders icon-only buttons, duration chip, and T-Bar', (tester) async {
    bool cutCalled = false;
    bool fadeCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () => cutCalled = true,
                onFade: () => fadeCalled = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify CUT icon button exists and has tooltip
    final cutButtonFinder = find.byKey(const Key('transition_cut_button'));
    expect(cutButtonFinder, findsOneWidget);
    await tester.tap(cutButtonFinder);
    expect(cutCalled, isTrue);

    // Verify FADE icon button exists and has tooltip
    final fadeButtonFinder = find.byKey(const Key('transition_fade_button'));
    expect(fadeButtonFinder, findsOneWidget);
    await tester.tap(fadeButtonFinder);
    expect(fadeCalled, isTrue);

    // Verify initial duration chip displays 300ms
    expect(find.text('300ms'), findsOneWidget);

    // Verify PRV, PGM, and percentage readout are removed from T-Bar
    expect(find.text('PRV'), findsNothing);
    expect(find.text('PGM'), findsNothing);
    expect(find.textContaining('%'), findsNothing);

    // Verify T-Bar track and handle exist
    expect(find.byKey(const Key('tbar_slider_track')), findsOneWidget);
    expect(find.byKey(const Key('tbar_slider_handle')), findsOneWidget);
  });

  testWidgets('Tapping duration chip opens modal and allows selecting presets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () {},
                onFade: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap duration chip
    final durationChipFinder = find.byKey(const Key('transition_duration_selector'));
    await tester.tap(durationChipFinder);
    await tester.pumpAndSettle();

    // Verify modal bottom sheet opened
    expect(find.text('TRANSITION DURATION'), findsOneWidget);
    expect(find.text('QUICK PRESETS'), findsOneWidget);
    expect(find.text('500ms'), findsOneWidget);

    // Select 500ms preset
    await tester.tap(find.text('500ms'));
    await tester.pumpAndSettle();

    // Verify duration updated in storage
    expect(storage.getTransitionDuration(), equals(500));

    // Close modal
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    // Verify main chip displays updated 500ms
    expect(find.text('500ms'), findsOneWidget);
  });

  testWidgets('SwitcherScreen in portrait mode places StudioTransitionControl underneath Preview and Program in Studio Mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );

    // Set connected and studio mode enabled
    container.read(obsProvider.notifier).setMockState(
      status: ObsConnectionStatus.connected,
      stats: const ObsStats(
        studioModeEnabled: true,
        currentProgramScene: 'PGM Scene',
        currentPreviewScene: 'PRV Scene',
      ),
    );

    container.read(scenesProvider);
    final broadcastService = container.read(broadcastServiceProvider);
    broadcastService.onScenesUpdated?.call(
      const [
        ObsScene(name: 'PRV Scene', sceneIndex: 0),
        ObsScene(name: 'PGM Scene', sceneIndex: 1),
      ],
      'PGM Scene',
      'PRV Scene',
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

    // Verify StudioTransitionControl is mounted
    final transitionControlFinder = find.byType(StudioTransitionControl);
    expect(transitionControlFinder, findsOneWidget);

    // Verify Preview scene and Program scene exist
    expect(find.text('PRV Scene'), findsWidgets);
    expect(find.text('PGM Scene'), findsWidgets);

    // Verify horizontal positioning: Preview is on the left, Program is on the right
    final prvRect = tester.getRect(find.widgetWithText(ScenePreviewBox, 'PRV Scene').first);
    final pgmRect = tester.getRect(find.widgetWithText(ScenePreviewBox, 'PGM Scene').first);
    final transitionRect = tester.getRect(transitionControlFinder);

    expect(prvRect.right, lessThanOrEqualTo(pgmRect.left + 1.0));

    // Verify vertical positioning: StudioTransitionControl is placed UNDER both Preview and Program
    expect(transitionRect.top, greaterThanOrEqualTo(prvRect.bottom - 1.0));
    expect(transitionRect.top, greaterThanOrEqualTo(pgmRect.bottom - 1.0));

    // Verify slider width matches trigger and settings container width (not full-width)
    final cutRect = tester.getRect(find.byKey(const Key('transition_cut_button')));
    final durationRect = tester.getRect(find.byKey(const Key('transition_duration_selector')));
    final trackRect = tester.getRect(find.byKey(const Key('tbar_slider_track')));

    expect(trackRect.left, closeTo(cutRect.left, 1.0));
    expect(trackRect.right, closeTo(durationRect.right, 1.0));
    expect(trackRect.width, closeTo(durationRect.right - cutRect.left, 1.0));
    expect(trackRect.width, lessThan(300.0));
  });

  testWidgets('LandscapeMultiviewScreen places StudioTransitionControl in the middle of Preview and Program in Studio Mode', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );

    container.read(obsProvider.notifier).setMockState(
      status: ObsConnectionStatus.connected,
      stats: const ObsStats(
        studioModeEnabled: true,
        currentProgramScene: 'Live Camera',
        currentPreviewScene: 'Media Slide',
      ),
    );

    container.read(scenesProvider);
    final broadcastService = container.read(broadcastServiceProvider);
    broadcastService.onScenesUpdated?.call(
      const [
        ObsScene(name: 'Media Slide', sceneIndex: 0),
        ObsScene(name: 'Live Camera', sceneIndex: 1),
      ],
      'Live Camera',
      'Media Slide',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: LandscapeMultiviewScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final transitionControlFinder = find.byType(StudioTransitionControl);
    expect(transitionControlFinder, findsOneWidget);

    final prvRect = tester.getRect(find.widgetWithText(ScenePreviewBox, 'Media Slide').first);
    final centerRect = tester.getRect(transitionControlFinder);
    final pgmRect = tester.getRect(find.widgetWithText(ScenePreviewBox, 'Live Camera').first);

    expect(prvRect.right, lessThanOrEqualTo(centerRect.left + 1.0));
    expect(centerRect.right, lessThanOrEqualTo(pgmRect.left + 1.0));

    // Verify CUT, FADE, and Duration Settings buttons have identical height and width
    final cutRect = tester.getRect(find.byKey(const Key('transition_cut_button')));
    final fadeRect = tester.getRect(find.byKey(const Key('transition_fade_button')));
    final durationRect = tester.getRect(find.byKey(const Key('transition_duration_selector')));

    expect(cutRect.height, equals(30.0));
    expect(fadeRect.height, equals(30.0));
    expect(durationRect.height, equals(30.0));

    expect(cutRect.width, closeTo(fadeRect.width, 1.0));
    expect(cutRect.width, closeTo(durationRect.width, 1.0));
  });

  testWidgets('T-Bar slider allows freely sliding to any position and holds it without unwanted snapback', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () {},
                onFade: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify PRV, PGM, and % labels are absent
    expect(find.text('PRV'), findsNothing);
    expect(find.text('PGM'), findsNothing);
    expect(find.textContaining('%'), findsNothing);

    // Find the T-Bar track and handle
    final trackFinder = find.byKey(const Key('tbar_slider_track'));
    final handleFinder = find.byKey(const Key('tbar_slider_handle'));
    expect(trackFinder, findsOneWidget);
    expect(handleFinder, findsOneWidget);

    final trackRect = tester.getRect(trackFinder);
    final initialHandleRect = tester.getRect(handleFinder);
    expect(initialHandleRect.left, closeTo(trackRect.left, 2.0));

    // Drag handle to middle (~50% position)
    final gesture = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await gesture.moveTo(trackRect.center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify handle holds at ~50% position
    final midHandleRect = tester.getRect(handleFinder);
    expect(midHandleRect.center.dx, closeTo(trackRect.center.dx, 5.0));

    // Still no percentage text displayed
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('T-Bar completes transition when dragged to 100% and resets to 0', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () {},
                onFade: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trackFinder = find.byKey(const Key('tbar_slider_track'));
    final handleFinder = find.byKey(const Key('tbar_slider_handle'));
    final trackRect = tester.getRect(trackFinder);

    // Drag handle all the way to the right (100% Program position)
    final gesture = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await gesture.moveTo(trackRect.centerRight - const Offset(2, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify it completed transition and returned handle to 0
    final resetHandleRect = tester.getRect(handleFinder);
    expect(resetHandleRect.left, closeTo(trackRect.left, 2.0));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('T-Bar smoothly glides to complete transition when released near Program end', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () {},
                onFade: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trackFinder = find.byKey(const Key('tbar_slider_track'));
    final handleFinder = find.byKey(const Key('tbar_slider_handle'));
    final trackRect = tester.getRect(trackFinder);

    // Drag handle to ~90% (near end) and release
    final gesture = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await gesture.moveTo(trackRect.centerRight - const Offset(8, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Handle completes and smoothly returns to 0
    final finalHandleRect = tester.getRect(handleFinder);
    expect(finalHandleRect.left, closeTo(trackRect.left, 2.0));
  });

  testWidgets('T-Bar slider rail is non-interactive and only handle can be grabbed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () {},
                onFade: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trackFinder = find.byKey(const Key('tbar_slider_track'));
    final trackRect = tester.getRect(trackFinder);
    final handleFinder = find.byKey(const Key('tbar_slider_handle'));

    final initialHandleRect = tester.getRect(handleFinder);

    // 1. Touch/tap on the rail at 70% of the track (far from the handle at 0%)
    await tester.tapAt(trackRect.centerLeft + const Offset(70, 0));
    await tester.pumpAndSettle();

    // Verify rail tap was ignored (handle stayed at initial position)
    expect(tester.getRect(handleFinder).left, closeTo(initialHandleRect.left, 1.0));

    // 2. Drag on the rail starting at 70%
    final railDrag = await tester.startGesture(trackRect.centerLeft + const Offset(70, 0));
    await tester.pump();
    await railDrag.moveTo(trackRect.centerRight - const Offset(5, 0));
    await tester.pump();
    await railDrag.up();
    await tester.pumpAndSettle();

    // Verify rail drag was ignored (handle stayed at initial position)
    expect(tester.getRect(handleFinder).left, closeTo(initialHandleRect.left, 1.0));

    // 3. Now grab the handle directly using its key
    final handleDrag = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await handleDrag.moveBy(const Offset(40, 0));
    await tester.pump();
    await handleDrag.up();
    await tester.pumpAndSettle();

    // Verify the handle was dragged and is holding transition
    expect(tester.getRect(handleFinder).left, greaterThan(initialHandleRect.left + 20));
  });

  testWidgets('T-Bar enforces cooldown delay after transition, locking handle until cooldown expires', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StudioTransitionControl(
                width: 100,
                onCut: () {},
                onFade: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trackFinder = find.byKey(const Key('tbar_slider_track'));
    final handleFinder = find.byKey(const Key('tbar_slider_handle'));
    final trackRect = tester.getRect(trackFinder);

    // 1. Drag handle to completion (100%) and release
    final gesture = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await gesture.moveTo(trackRect.centerRight - const Offset(2, 0));
    await tester.pump();
    await gesture.up();

    // Pump through the 180ms return animation
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 60));

    // Handle is back at 0.0, but within the cooldown period (400ms delay)
    final initialResetRect = tester.getRect(handleFinder);
    expect(initialResetRect.left, closeTo(trackRect.left, 2.0));

    // 2. Attempt to immediately drag handle while in cooldown (100ms into cooldown)
    await tester.pump(const Duration(milliseconds: 100));
    final lockedGesture = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await lockedGesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await lockedGesture.up();

    // Verify handle was NOT moved because cooldown is active
    expect(tester.getRect(handleFinder).left, closeTo(initialResetRect.left, 2.0));

    // 3. Advance past the full cooldown duration
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 4. Now drag the handle again after cooldown has elapsed
    final newGesture = await tester.startGesture(tester.getCenter(handleFinder));
    await tester.pump();
    await newGesture.moveBy(const Offset(35, 0));
    await tester.pump();
    await newGesture.up();
    await tester.pumpAndSettle();

    // Handle successfully dragged after cooldown
    expect(tester.getRect(handleFinder).left, greaterThan(initialResetRect.left + 15));
  });
}
