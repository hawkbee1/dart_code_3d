import 'package:dart_code_3d/analysis/widgets/rules_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RulesSummary, () {
    late int edited;

    setUp(() => edited = 0);

    Future<void> pump(
      WidgetTester tester,
      AnalysisRules rules, {
      Locale locale = const Locale('en'),
    }) => tester.pumpApp(
      Scaffold(
        body: RulesSummary(rules: rules, onEdit: () => edited++),
      ),
      locale: locale,
    );

    testWidgets('says the rules are the defaults when nothing changed', (
      tester,
    ) async {
      await pump(tester, AnalysisRules.defaults());

      expect(find.text('Analysis rules'), findsOneWidget);
      expect(find.text('Default rules'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('highlights each rule that was changed, with its value', (
      tester,
    ) async {
      final rules = AnalysisRules.defaults()
          .copyWith(RuleIds.excludeTests, false)
          .copyWith(RuleIds.ambiguousCalls, 'skip');

      await pump(tester, rules);

      expect(find.text('2 rules differ from the defaults'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('Skip tests: Off'), findsOneWidget);
      expect(find.textContaining(': Drop them'), findsOneWidget);
    });

    testWidgets('counts a single change in the singular', (tester) async {
      await pump(
        tester,
        AnalysisRules.defaults().copyWith(RuleIds.excludeTests, false),
      );

      expect(find.text('1 rule differs from the defaults'), findsOneWidget);
    });

    testWidgets('asks to edit the rules', (tester) async {
      await pump(tester, AnalysisRules.defaults());

      await tester.tap(find.text('Edit rules'));

      expect(edited, 1);
    });

    testWidgets('speaks French', (tester) async {
      await pump(
        tester,
        AnalysisRules.defaults().copyWith(RuleIds.excludeTests, false),
        locale: const Locale('fr'),
      );

      expect(find.text('Règles d’analyse'), findsOneWidget);
      expect(
        find.text('1 règle diffère des valeurs par défaut'),
        findsOneWidget,
      );
    });
  });
}
