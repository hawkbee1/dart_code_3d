import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/helpers.dart';
import '../../helpers/settings.dart';

void main() {
  group(SettingsPage, () {
    late MockSettingsBloc bloc;

    setUpAll(() => registerFallbackValue(const SettingsRulesReset()));

    setUp(() => bloc = settingsBlocWith());

    Future<void> pump(WidgetTester tester, {Widget? view}) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(view ?? const SettingsPage(), settingsBloc: bloc);
    }

    /// The text field of rule [id], scrolled into view.
    Future<Finder> ruleField(WidgetTester tester, String id) async {
      final rule = find.byKey(ValueKey(id));
      await tester.scrollUntilVisible(
        rule,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      return find.descendant(of: rule, matching: find.byType(TextField));
    }

    testWidgets('meets the tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('changes the theme mode', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Dark'));

      verify(() => bloc.add(const SettingsThemeModeChanged(AppThemeMode.dark)))
          .called(1);
    });

    testWidgets('changes the theme mode with large text', (tester) async {
      await tester.pumpApp(
        const SettingsPage(),
        settingsBloc: bloc,
        textScale: 2,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Light'));

      verify(() => bloc.add(const SettingsThemeModeChanged(AppThemeMode.light)))
          .called(1);
    });

    testWidgets('toggles a boolean rule', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Imports'));

      verify(
        () => bloc.add(const SettingsRuleChanged(RuleIds.linksImports, true)),
      ).called(1);
    });

    testWidgets('picks an enabled option', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Link every candidate'));

      verify(
        () =>
            bloc.add(const SettingsRuleChanged(RuleIds.ambiguousCalls, 'all')),
      ).called(1);
    });

    testWidgets('explains a disabled option instead of picking it', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Full resolution'));
      await tester.pumpAndSettle();

      expect(find.text('Not available yet'), findsOneWidget);
      expect(find.textContaining('Coming later'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<SettingsRuleChanged>())));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Not available yet'), findsNothing);
    });

    testWidgets('toggles members on and off', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Getters'));

      verify(
        () => bloc.add(
          const SettingsRuleChanged(RuleIds.memberKinds, {
            'method',
            'constructor',
            'setter',
          }),
        ),
      ).called(1);
    });

    testWidgets('adds a member kind back', (tester) async {
      bloc = settingsBlocWith(
        SettingsState(
          status: SettingsStatus.ready,
          rules: AnalysisRules.defaults().copyWith(RuleIds.memberKinds, {
            'method',
          }),
        ),
      );
      await pump(tester);

      await tester.tap(find.text('Setters'));

      verify(
        () => bloc.add(
          const SettingsRuleChanged(RuleIds.memberKinds, {'method', 'setter'}),
        ),
      ).called(1);
    });

    testWidgets('adds, refuses and removes glob patterns', (tester) async {
      await pump(tester);
      final field = find
          .widgetWithText(TextField, 'Add a pattern, e.g. **/*.freezed.dart')
          .first;

      await tester.enterText(field, '[broken');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Not a valid pattern'), findsOneWidget);

      await tester.enterText(field, '**/*.freezed.dart');
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey(RuleIds.generatedPatterns)),
          matching: find.byTooltip('Add pattern'),
        ),
      );
      await tester.pump();
      verify(
        () => bloc.add(
          const SettingsRuleChanged(RuleIds.generatedPatterns, [
            '**/*.g.dart',
            '**/*.freezed.dart',
          ]),
        ),
      ).called(1);
      expect(find.text('Not a valid pattern'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, '**/*.g.dart'),
          matching: find.byType(Icon),
        ),
      );
      verify(
        () => bloc.add(
          const SettingsRuleChanged(RuleIds.generatedPatterns, <String>[]),
        ),
      ).called(1);
    });

    testWidgets('edits a text rule and refuses an empty value', (tester) async {
      await pump(tester);
      final field = await ruleField(tester, RuleIds.entryPoint);

      await tester.enterText(field, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Must not be empty'), findsOneWidget);

      await tester.enterText(field, 'bin/tool.dart');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verify(
        () => bloc.add(
          const SettingsRuleChanged(RuleIds.entryPoint, 'bin/tool.dart'),
        ),
      ).called(1);
    });

    testWidgets('shows a text rule changed elsewhere (e.g. reset)', (
      tester,
    ) async {
      final changed = StreamController<SettingsState>();
      addTearDown(changed.close);
      whenListen(
        bloc,
        changed.stream,
        initialState: SettingsState(status: SettingsStatus.ready),
      );
      await pump(tester);
      final field = await ruleField(tester, RuleIds.entryPoint);

      changed.add(
        SettingsState(
          status: SettingsStatus.ready,
          rules: AnalysisRules.defaults().copyWith(
            RuleIds.entryPoint,
            'lib/main_development.dart',
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<TextField>(field).controller!.text,
        'lib/main_development.dart',
      );
    });

    testWidgets('resets the rules only after confirmation', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(const SettingsRulesReset()));

      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const SettingsRulesReset())).called(1);
    });

    testWidgets('shows any rule of the catalog without UI code', (
      tester,
    ) async {
      const flag = BoolParameter(
        id: 'test.flag',
        title: 'A brand new rule',
        description: 'Added to the catalog only.',
        group: RuleGroup.analysis,
        defaultValue: false,
      );
      bloc = settingsBlocWith(
        SettingsState(
          status: SettingsStatus.ready,
          rules: AnalysisRules.defaults(catalog: const [flag]),
        ),
      );

      await pump(tester, view: const SettingsView(catalog: [flag]));

      expect(find.text('A brand new rule'), findsOneWidget);
      expect(find.text('Added to the catalog only.'), findsOneWidget);
      expect(find.text('Files'), findsNothing);
    });

    testWidgets('falls back to the catalog texts for unknown options', (
      tester,
    ) async {
      const choice = EnumParameter(
        id: 'test.choice',
        title: 'Choice',
        description: 'd',
        group: RuleGroup.nodes,
        defaultValue: 'a',
        options: [
          RuleOption('a', 'Option A'),
          RuleOption('b', 'Option B', enabled: false),
        ],
      );
      bloc = settingsBlocWith(
        SettingsState(
          status: SettingsStatus.ready,
          rules: AnalysisRules.defaults(catalog: const [choice]),
        ),
      );
      await pump(tester, view: const SettingsView(catalog: [choice]));

      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Not available yet'), findsOneWidget);
    });
  });
}
