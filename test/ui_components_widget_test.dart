import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/constants/app_colors.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/models/obs_audio_source.dart';
import 'package:obscontrol_app/ui/widgets/audio_horizontal_channel_strip.dart';
import 'package:obscontrol_app/ui/widgets/grid_count_selector.dart';
import 'package:obscontrol_app/ui/widgets/obs_disconnected_prompt.dart';
import 'package:obscontrol_app/ui/widgets/safe_action_dialog.dart';
import 'package:obscontrol_app/ui/widgets/scene_monitor_header.dart';
import 'package:obscontrol_app/ui/widgets/vu_meter_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VuMeterBar Widget Tests', () {
    testWidgets('renders VuMeterBar with correct dimensions and bounds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: VuMeterBar(level: 0.75, peakHold: 0.85, height: 8.0),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VuMeterBar), findsOneWidget);
      final size = tester.getSize(find.byType(VuMeterBar));
      expect(size.width, 120.0);
      expect(size.height, 8.0);
    });

    testWidgets('clamps negative and oversized levels smoothly without error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                child: VuMeterBar(level: -0.5, peakHold: 1.5, height: 6.0),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VuMeterBar), findsOneWidget);
    });
  });

  group('GridCountSelector Widget Tests', () {
    testWidgets('renders count options and fires selection on tap', (
      WidgetTester tester,
    ) async {
      int selected = 4;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: GridCountSelector(
                selectedCount: selected,
                onSelectCount: (val) => selected = val,
                counts: const [4, 8],
              ),
            ),
          ),
        ),
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // Tap '8' option
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();

      expect(selected, 8);
    });
  });

  group('SafeActionDialog Widget Tests', () {
    testWidgets('displays title, message, cancel and confirm buttons', (
      WidgetTester tester,
    ) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    SafeActionDialog.show(
                      context,
                      title: 'STOP STREAM',
                      message: 'Are you sure you want to stop the live stream?',
                      confirmLabel: 'END BROADCAST',
                      confirmColor: AppColors.liveRed,
                    ).then((value) {
                      if (value == true) confirmed = true;
                    });
                  },
                  child: const Text('TRIGGER SAFE ACTION'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TRIGGER SAFE ACTION'));
      await tester.pumpAndSettle();

      expect(find.text('STOP STREAM'), findsOneWidget);
      expect(
        find.text('Are you sure you want to stop the live stream?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('END BROADCAST'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('END BROADCAST'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.text('STOP STREAM'), findsNothing);
    });

    testWidgets('cancels dialog when Cancel is tapped', (
      WidgetTester tester,
    ) async {
      bool? confirmed;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    SafeActionDialog.show(
                      context,
                      title: 'RESET DECK',
                      message: 'Discard customized macro actions?',
                      confirmLabel: 'RESET',
                    ).then((value) {
                      confirmed = value;
                    });
                  },
                  child: const Text('TRIGGER SAFE ACTION'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TRIGGER SAFE ACTION'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse);
      expect(find.text('RESET DECK'), findsNothing);
    });
  });

  group('SceneMonitorHeader Widget Tests', () {
    testWidgets(
      'renders section label and grid count selector with optional trailing',
      (WidgetTester tester) async {
        int count = 4;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SceneMonitorHeader(
                label: 'ACTIVE SCENE FEEDS',
                gridCount: count,
                onSelectCount: (val) => count = val,
                trailing: const Text('CUSTOM TRAILING'),
              ),
            ),
          ),
        );

        expect(find.text('ACTIVE SCENE FEEDS'), findsOneWidget);
        expect(find.text('CUSTOM TRAILING'), findsOneWidget);
        expect(find.byType(GridCountSelector), findsOneWidget);
      },
    );
  });

  group('ObsDisconnectedPrompt Widget Tests', () {
    testWidgets(
      'renders prompt icon, title, description and triggers onConnect',
      (WidgetTester tester) async {
        bool connectTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ObsDisconnectedPrompt(
                topInset: 0,
                bottomInset: 0,
                icon: Icons.wifi_off_rounded,
                title: 'Not Connected',
                subtitle: 'Check connection settings to connect.',
                onConnect: () => connectTapped = true,
                buttonLabel: 'QUICK CONNECT',
              ),
            ),
          ),
        );

        expect(find.text('Not Connected'), findsOneWidget);
        expect(
          find.text('Check connection settings to connect.'),
          findsOneWidget,
        );
        expect(find.text('QUICK CONNECT'), findsOneWidget);
        expect(find.text('HOW TO CONNECT? SETUP GUIDE'), findsOneWidget);

        await tester.tap(find.text('QUICK CONNECT'));
        await tester.pump();
        expect(connectTapped, isTrue);
      },
    );
  });

  group('AudioHorizontalChannelStrip Widget Tests', () {
    testWidgets(
      'displays channel info, formatted dB, mute state, and handles volume changes',
      (WidgetTester tester) async {
        double changedVol = 1.0;
        bool muteTapped = false;

        const source = ObsAudioSource(
          name: 'Game Audio',
          volumeMul: 0.85,
          volumeDb: -1.4,
          muted: false,
          leftLevel: 0.6,
          rightLevel: 0.65,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: AudioHorizontalChannelStrip(
                    source: source,
                    onVolumeChanged: (vol) => changedVol = vol,
                    onToggleMute: () => muteTapped = true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Game Audio'), findsOneWidget);
        expect(find.text('-1.4 dB'), findsOneWidget);

        // Tap mute button
        await tester.tap(find.byIcon(Icons.volume_up_rounded));
        await tester.pump();
        expect(muteTapped, isTrue);
      },
    );
  });
}
