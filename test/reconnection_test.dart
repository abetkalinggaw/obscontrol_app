import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.init();
  });

  group('Reconnection & Profile Persistence Tests', () {
    test('StorageService getAutoReconnect defaults to true', () {
      expect(storageService.getAutoReconnect(), isTrue);
    });

    test('SettingsNotifier updateActiveProfileConnection updates active profile', () async {
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
      );

      final notifier = container.read(settingsProvider.notifier);
      await notifier.updateActiveProfileConnection(
        host: '192.168.1.150',
        port: 4455,
        password: 'secure_password',
        software: StreamingSoftware.obsStudio,
      );

      final state = container.read(settingsProvider);
      final active = state.activeProfile;

      expect(active.host, '192.168.1.150');
      expect(active.port, 4455);
      expect(active.password, 'secure_password');
      expect(active.software, StreamingSoftware.obsStudio);
    });

    test('SettingsNotifier matches existing profile and switches activeProfileId', () async {
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
      );

      final notifier = container.read(settingsProvider.notifier);
      final p1 = ObsConnectionProfile(
        id: 'laptop_vmix',
        name: 'Laptop vMix',
        host: '192.168.1.200',
        port: 8088,
        password: '',
        software: StreamingSoftware.vmix,
        lastUsed: DateTime.now(),
      );
      await notifier.saveProfile(p1);

      // Now quick connect to that same machine
      await notifier.updateActiveProfileConnection(
        host: '192.168.1.200',
        port: 8088,
        password: 'vmix_pw',
        software: StreamingSoftware.vmix,
      );

      final state = container.read(settingsProvider);
      expect(state.activeProfileId, 'laptop_vmix');
      expect(state.activeProfile.password, 'vmix_pw');
    });

    test('ObsNotifier disconnect tracks explicit user disconnection', () {
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
      );

      final obsNotifier = container.read(obsProvider.notifier);
      expect(obsNotifier.userExplicitlyDisconnected, isFalse);

      obsNotifier.disconnect();
      expect(obsNotifier.userExplicitlyDisconnected, isTrue);
    });

    testWidgets('ObsControlApp mounts and registers lifecycle observer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storageService),
          ],
          child: const ObsControlApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ObsControlApp), findsOneWidget);

      // Simulate app going to background and resuming
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byType(ObsControlApp), findsOneWidget);
    });
  });
}
