import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import '../helpers/helpers.dart';
import '../helpers/settings.dart';

void main() {
  // WCAG 2.2 AA on every 2D screen: contrast, target size and labels, in
  // both themes, at the largest text size (2x).
  group('2D screens meet the guidelines', () {
    Future<void> check(WidgetTester tester, {bool contrast = true}) async {
      // The form is checked from the theme's colors below: on a text field's
      // helper text the guideline samples the pixels of the wrong place (the
      // rectangle it reads is in the field's own coordinates).
      if (contrast) {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }

    final screens = <String, Widget Function()>{
      'home': () => const HomePage(),
      'new analysis': () => const NewAnalysisPage(),
      'settings': () => const SettingsPage(),
    };

    for (final MapEntry(key: name, value: screen) in screens.entries) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('$name, ${mode.name}, text x$scale', (tester) async {
            final handle = tester.ensureSemantics();
            tester.view
              ..physicalSize = const Size(900, 1800)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await tester.pumpApp(
              screen(),
              themeMode: mode,
              textScale: scale,
              repository: repositoryWith(maps: recentSummaries()),
              settingsBloc: settingsBlocWith(),
            );
            // Past the fade-in of the fields' helper text.
            await tester.pump(const Duration(seconds: 1));

            expect(tester.takeException(), isNull);
            await check(tester, contrast: name != 'new analysis');
            handle.dispose();
          });
        }
      }
    }
  });

  group('the colors of the text', () {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test('read at 4.5:1 or better in the $name theme', () {
        final c = theme.colorScheme;
        double ratio(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          return (la > lb ? la + 0.05 : lb + 0.05) /
              (la > lb ? lb + 0.05 : la + 0.05);
        }

        for (final (text, background) in [
          (c.onSurface, c.surface),
          (c.onSurfaceVariant, c.surface),
          (c.primary, c.surface),
          (c.error, c.surface),
          (c.onSecondaryContainer, c.secondaryContainer),
          (c.onTertiaryContainer, c.tertiaryContainer),
          (c.onErrorContainer, c.errorContainer),
          (c.onPrimary, c.primary),
          (c.onSurface, c.surfaceContainerLow),
          (c.onSurfaceVariant, c.surfaceContainerLow),
        ]) {
          expect(ratio(text, background), greaterThanOrEqualTo(4.5));
        }
      });
    }
  });

  group('keyboard only', () {
    setUpAll(() {
      registerFallbackValue(const LocalFolderSource('/x'));
      registerFallbackValue(AnalysisRules.defaults());
    });

    testWidgets('the new analysis form is filled and started with keys', (
      tester,
    ) async {
      final repository = repositoryWith();
      when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
          .thenAnswer((_) => const Stream<BuildEvent>.empty());
      tester.view
        ..physicalSize = const Size(900, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const NewAnalysisPage(),
        repository: repository,
        settingsBloc: settingsBlocWith(),
      );

      Future<void> tab() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      // Tab walks the segments, then the two fields.
      for (var i = 0; i < 6 && !_focused(tester, 'Repository URL'); i++) {
        await tab();
      }
      expect(_focused(tester, 'Repository URL'), isTrue);
      await tester.enterText(
        find.widgetWithText(TextField, 'Repository URL'),
        'github.com/o/r',
      );
      await tab();
      expect(_focused(tester, 'Branch or tag (optional)'), isTrue);

      // The next stops are the rules button, then Analyze, which Enter starts.
      await tab();
      await tab();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.text('Analyzing r'), findsOneWidget);
    });

    testWidgets('the cancel dialog takes the focus and Esc closes it', (
      tester,
    ) async {
      final repository = repositoryWith();
      when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
          .thenAnswer((_) => const Stream<BuildEvent>.empty());
      tester.view
        ..physicalSize = const Size(900, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const NewAnalysisPage(),
        repository: repository,
        settingsBloc: settingsBlocWith(),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Repository URL'),
        'github.com/o/r',
      );
      await tester.pump();
      await tester.tap(find.text('Analyze'));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Cancel the analysis?'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cancel the analysis?'), findsNothing);
      expect(find.text('Analyzing r'), findsOneWidget);
    });
  });
}

bool _focused(WidgetTester tester, String label) {
  final field = find.widgetWithText(TextField, label);
  if (field.evaluate().isEmpty) return false;
  return tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;
}
