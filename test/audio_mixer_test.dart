import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/models/obs_audio_source.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/ui/dialogs/audio_channel_visibility_dialog.dart';
import 'package:obscontrol_app/ui/screens/audio_mixer_screen.dart';
import 'package:obscontrol_app/ui/widgets/audio_channel_strip.dart';
import 'package:obscontrol_app/ui/widgets/audio_horizontal_channel_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'AudioMixerScreen supports icon-only view toggling between vertical and horizontal views',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(
                  body: AudioMixerScreen(),
                ),
              );
            },
          ),
        ),
      );

      // Simulate connected OBS state with audio channels
      container.read(obsProvider.notifier).setMockState(
        status: ObsConnectionStatus.connected,
      );

      final obsService = container.read(obsWebSocketServiceProvider);
      obsService.onAudioSourcesUpdated?.call([
        const ObsAudioSource(
          name: 'Mic/Aux',
          volumeMul: 0.8,
          volumeDb: -2.0,
          leftLevel: 0.5,
          rightLevel: 0.5,
        ),
        const ObsAudioSource(
          name: 'Desktop Audio',
          volumeMul: 1.0,
          volumeDb: 0.0,
          leftLevel: 0.3,
          rightLevel: 0.3,
        ),
      ]);

      await tester.pumpAndSettle();

      // View selector buttons should be icon-only (no 'VERT' or 'HORIZ' text labels)
      expect(find.text('VERT'), findsNothing);
      expect(find.text('HORIZ'), findsNothing);
      expect(find.text('2 CHANNELS'), findsOneWidget);

      // Verify view mode icon buttons exist
      expect(find.byIcon(Icons.view_week_rounded), findsOneWidget);
      expect(find.byIcon(Icons.table_rows_rounded), findsOneWidget);

      // Default view should be vertical (AudioChannelStrip)
      expect(find.byType(AudioChannelStrip), findsNWidgets(2));
      expect(find.byType(AudioHorizontalChannelStrip), findsNothing);

      // Tap horizontal view icon button
      await tester.tap(find.byIcon(Icons.table_rows_rounded));
      await tester.pumpAndSettle();

      // Should now render horizontal strips (AudioHorizontalChannelStrip)
      expect(find.byType(AudioHorizontalChannelStrip), findsNWidgets(2));
      expect(find.byType(AudioChannelStrip), findsNothing);

      // Tap vertical view icon button
      await tester.tap(find.byIcon(Icons.view_week_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AudioChannelStrip), findsNWidgets(2));
      expect(find.byType(AudioHorizontalChannelStrip), findsNothing);
    },
  );

  testWidgets(
    'AudioMixerScreen supports selecting audio channels to hide and show',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(
                  body: AudioMixerScreen(),
                ),
              );
            },
          ),
        ),
      );

      container.read(obsProvider.notifier).setMockState(
        status: ObsConnectionStatus.connected,
      );

      final obsService = container.read(obsWebSocketServiceProvider);
      obsService.onAudioSourcesUpdated?.call([
        const ObsAudioSource(name: 'Mic/Aux'),
        const ObsAudioSource(name: 'Desktop Audio'),
        const ObsAudioSource(name: 'Spotify Music'),
      ]);

      await tester.pumpAndSettle();

      expect(find.text('3 CHANNELS'), findsOneWidget);
      expect(find.byType(AudioChannelStrip), findsNWidgets(3));

      // Tap the channel visibility button
      await tester.tap(find.byTooltip('Show/Hide Audio Channels'));
      await tester.pumpAndSettle();

      // Modal sheet should appear
      expect(find.byType(AudioChannelVisibilitySheet), findsOneWidget);
      expect(find.text('AUDIO CHANNEL VISIBILITY'), findsOneWidget);
      expect(find.text('3 of 3 visible'), findsOneWidget);

      // Tap 'Spotify Music' in the sheet list to hide it
      await tester.tap(find.descendant(
        of: find.byType(AudioChannelVisibilitySheet),
        matching: find.text('Spotify Music'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2 of 3 visible'), findsOneWidget);

      // Tap DONE to close sheet
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // Mixer header should now indicate 2/3 channels
      expect(find.text('2/3 CHANNELS'), findsOneWidget);
      expect(find.byType(AudioChannelStrip), findsNWidgets(2));
      expect(find.text('Spotify Music'), findsNothing);
      expect(find.text('Mic/Aux'), findsOneWidget);
      expect(find.text('Desktop Audio'), findsOneWidget);

      // Open sheet again and tap HIDE ALL
      await tester.tap(find.byTooltip('Show/Hide Audio Channels'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('HIDE ALL'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // All channels hidden empty state
      expect(find.text('All Channels Hidden'), findsOneWidget);
      expect(find.byType(AudioChannelStrip), findsNothing);

      // Tap SHOW ALL from the empty state
      await tester.tap(find.text('SHOW ALL'));
      await tester.pumpAndSettle();

      // All 3 channels should be back
      expect(find.text('3 CHANNELS'), findsOneWidget);
      expect(find.byType(AudioChannelStrip), findsNWidgets(3));
    },
  );
}
