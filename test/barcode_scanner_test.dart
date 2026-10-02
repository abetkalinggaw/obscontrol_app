import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/services/storage_service.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/providers/settings_provider.dart';
import 'package:obscontrol_app/ui/screens/barcode_scanner_screen.dart';
import 'package:obscontrol_app/ui/screens/connection_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'BarcodeScannerScreen renders header, instructions, and gallery button',
    (WidgetTester tester) async {
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
            home: const BarcodeScannerScreen(autoConnect: false),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify top bar title
      expect(find.text('OBS QR & BARCODE SCANNER'), findsOneWidget);

      // Verify instruction panel
      expect(find.text('ALIGN OBS STUDIO QR CODE IN FRAME'), findsOneWidget);

      // Gallery button replaces paste/sample
      expect(find.text('SELECT FROM GALLERY'), findsOneWidget);

      // Removed buttons should not exist
      expect(find.text('PASTE CODE'), findsNothing);
      expect(find.text('SAMPLE QR'), findsNothing);

      // Torch and flip camera controls
      expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flip_camera_ios_rounded), findsOneWidget);
    },
  );

  testWidgets('BarcodeScannerScreen gallery button is tappable without crash', (
    WidgetTester tester,
  ) async {
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
          home: const BarcodeScannerScreen(autoConnect: false),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Gallery button is present and tappable (image picker will silently fail in test env)
    expect(find.text('SELECT FROM GALLERY'), findsOneWidget);
    await tester.tap(find.text('SELECT FROM GALLERY'));
    await tester.pump(const Duration(milliseconds: 300));

    // No crash — error message may appear since picker returns null in test
    // Scanner screen should still be visible
    expect(find.text('OBS QR & BARCODE SCANNER'), findsOneWidget);
  });

  testWidgets(
    'ConnectionSettingsScreen includes Scan QR action and Auto-fill button',
    (WidgetTester tester) async {
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
            home: const Scaffold(body: ConnectionSettingsScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify quick action bar button exists
      expect(find.text('SCAN OBS WEBSOCKET QR CODE'), findsOneWidget);

      // Open Add Connection Profile dialog
      await tester.tap(find.text('ADD CONNECTION PROFILE'));
      await tester.pumpAndSettle();

      // Verify auto-fill button inside dialog exists
      expect(find.textContaining('AUTO-FILL'), findsOneWidget);
    },
  );
}
