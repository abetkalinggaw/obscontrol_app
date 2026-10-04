import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/core/services/discovery_service.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/models/connection_state.dart';
import 'package:obscontrol_app/providers/obs_provider.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/ui/dialogs/quick_connect_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiscoveryService tests', () {
    test('resolves software and names correctly', () {
      final sObs = DiscoveredObsServer(
        ip: '192.168.1.100',
        port: 4455,
        name: 'OBS Studio (192.168.1.100:4455)',
        software: StreamingSoftware.obsStudio,
      );
      expect(sObs.software, StreamingSoftware.obsStudio);
      expect(sObs.port, 4455);

      final sVmix = DiscoveredObsServer(
        ip: '192.168.1.105',
        port: 8088,
        name: 'vMix (192.168.1.105:8088)',
        software: StreamingSoftware.vmix,
      );
      expect(sVmix.software, StreamingSoftware.vmix);
      expect(sVmix.port, 8088);
    });

    test('immediately stops when isCancelled returns true', () async {
      var cancelled = true;
      final results = await DiscoveryService.scanLocalNetwork(
        isCancelled: () => cancelled,
      );
      expect(results, isEmpty);
    });

    test('discovers active socket and streams via onDiscovered', () async {
      final serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final mockPort = serverSocket.port;
      serverSocket.listen((client) {
        client.close();
      });

      final streamed = <DiscoveredObsServer>[];
      final results = await DiscoveryService.scanLocalNetwork(
        customPort: mockPort,
        preferredHost: '127.0.0.1',
        onDiscovered: (s) => streamed.add(s),
      );

      await serverSocket.close();

      expect(results.any((s) => s.port == mockPort), isTrue);
      expect(streamed.any((s) => s.port == mockPort), isTrue);
    });
  });

  group('QuickConnectSheet LAN Discovery & Input Button tests', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
    });

    testWidgets(
      'Tapping "Input" button on discovered server inputs data into form fields without connecting',
      (WidgetTester tester) async {
        const mockServer = DiscoveredObsServer(
          ip: '192.168.1.188',
          port: 4455,
          name: 'Studio Main (192.168.1.188:4455)',
          software: StreamingSoftware.obsStudio,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => QuickConnectSheet.show(
                        context,
                        discoveryScanner: ({
                          software,
                          customPort,
                          preferredHost,
                          onProgress,
                          onDiscovered,
                          isCancelled,
                        }) async {
                          onProgress?.call(0.5, 'Found instance!');
                          onDiscovered?.call(mockServer);
                          return [mockServer];
                        },
                      ),
                      child: const Text('OPEN QUICK CONNECT'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open sheet
        await tester.tap(find.text('OPEN QUICK CONNECT'));
        await tester.pumpAndSettle();

        // Verify initial text fields are empty
        final hostFieldFinder = find.byType(TextField).at(0);
        final portFieldFinder = find.byType(TextField).at(1);
        expect(tester.widget<TextField>(hostFieldFinder).controller?.text, isEmpty);
        expect(tester.widget<TextField>(portFieldFinder).controller?.text, isEmpty);

        // Verify Scan LAN button exists
        expect(find.text('Scan LAN'), findsOneWidget);

        // Tap Scan LAN
        await tester.tap(find.text('Scan LAN'));
        await tester.pumpAndSettle();

        // Verify "Input" button is rendered (and NOT "Connect" on the discovered item)
        expect(find.text('Input'), findsOneWidget);

        // Verify main top CONNECT button still exists
        expect(find.text('CONNECT'), findsOneWidget);

        // Tap the "Input" button
        await tester.tap(find.text('Input'));
        await tester.pumpAndSettle();

        // Check text fields: host and port should be populated!
        expect(
          tester.widget<TextField>(hostFieldFinder).controller?.text,
          '192.168.1.188',
        );
        expect(
          tester.widget<TextField>(portFieldFinder).controller?.text,
          '4455',
        );

        // Verify QuickConnectSheet is STILL open (not popped/dismissed)
        expect(find.text('Quick Connect'), findsOneWidget);
        expect(find.text('CONNECT'), findsOneWidget);

        // Verify obs provider status is still disconnected (did NOT auto-connect!)
        final element = tester.element(find.byType(QuickConnectSheet));
        final container = ProviderScope.containerOf(element);
        expect(container.read(obsProvider).status, ObsConnectionStatus.disconnected);
      },
    );

    testWidgets(
      'Tapping "Stop Scan" cancels the active scan',
      (WidgetTester tester) async {
        final completer = Completer<List<DiscoveredObsServer>>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => QuickConnectSheet.show(
                        context,
                        discoveryScanner: ({
                          software,
                          customPort,
                          preferredHost,
                          onProgress,
                          onDiscovered,
                          isCancelled,
                        }) async {
                          onProgress?.call(0.1, 'Scanning host...');
                          return completer.future;
                        },
                      ),
                      child: const Text('OPEN QUICK CONNECT'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open sheet
        await tester.tap(find.text('OPEN QUICK CONNECT'));
        await tester.pumpAndSettle();

        // Tap Scan LAN
        await tester.tap(find.text('Scan LAN'));
        await tester.pump();

        // "Stop Scan" button should be visible while scanning
        expect(find.text('Stop Scan'), findsOneWidget);

        // Tap Stop Scan
        await tester.tap(find.text('Stop Scan'));
        await tester.pump();

        // "Scan LAN" button should reappear and status text should reflect stopped
        expect(find.text('Scan LAN'), findsOneWidget);
        expect(find.text('Scan stopped.'), findsOneWidget);

        // Complete future so no hanging timers remain
        completer.complete([]);
        await tester.pumpAndSettle();
      },
    );
  });
}
