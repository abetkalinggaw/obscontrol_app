import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obscontrol_app/core/constants/app_theme.dart';
import 'package:obscontrol_app/models/macro_action.dart';
import 'package:obscontrol_app/ui/dialogs/edit_macro_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditMacroDialog Widget Tests', () {
    testWidgets(
      'renders macro editing form fields and pre-fills current action data',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        MacroAction? savedMacro;
        const initialMacro = MacroAction(
          id: 'macro-editing-1',
          title: 'MUTE MIC',
          subtitle: 'Toggle Host Mic',
          iconName: 'mic_off',
          colorValue: 0xFFFF3B30,
          type: MacroType.toggleMute,
          target: 'Mic/Aux',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: EditMacroDialog(
                macro: initialMacro,
                availableScenes: const ['Scene 1', 'Scene 2'],
                availableAudioSources: const ['Mic/Aux', 'Desktop Audio'],
                onSave: (updated) => savedMacro = updated,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Customize Macro Tile'), findsOneWidget);
        expect(find.text('Button Label'), findsOneWidget);
        expect(find.text('MUTE MIC'), findsOneWidget);
        expect(find.text('Toggle Host Mic'), findsOneWidget);
        expect(find.text('SAVE CHANGES'), findsOneWidget);

        // Edit title and submit
        await tester.enterText(
          find.widgetWithText(TextField, 'MUTE MIC'),
          'MUTE ALL',
        );
        await tester.tap(find.text('SAVE CHANGES'));
        await tester.pumpAndSettle();

        expect(savedMacro, isNotNull);
        expect(savedMacro!.title, 'MUTE ALL');
        expect(savedMacro!.id, 'macro-editing-1');
      },
    );
  });
}
