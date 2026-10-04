import 'package:dart_code_3d/settings/models/changed_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_repository/settings_repository.dart';

void main() {
  group(changedRules, () {
    test('is empty for the default rules', () {
      expect(changedRules(AnalysisRules.defaults()), isEmpty);
    });

    test('lists the rules that differ, in display order', () {
      final rules = AnalysisRules.defaults()
          .copyWith(RuleIds.excludeTests, false)
          .copyWith(RuleIds.includePrivate, false);

      expect(changedRules(rules).map((r) => r.id).toSet(), {
        RuleIds.excludeTests,
        RuleIds.includePrivate,
      });
      final order = RuleCatalog.all.map((r) => r.id).toList();
      final ids = changedRules(rules).map((r) => r.id).toList();
      expect(
        ids,
        [...ids]..sort((a, b) => order.indexOf(a) - order.indexOf(b)),
      );
    });

    test('sees a changed list', () {
      final rules = AnalysisRules.defaults().copyWith(
        RuleIds.generatedPatterns,
        const ['**/*.generated_by_me.dart'],
      );

      expect(
        changedRules(rules).map((r) => r.id),
        contains(RuleIds.generatedPatterns),
      );
    });

    test('does not see a value set to its default again', () {
      final rules = AnalysisRules.defaults().copyWith(
        RuleIds.excludeGenerated,
        true,
      );

      expect(changedRules(rules), isEmpty);
    });
  });
}
