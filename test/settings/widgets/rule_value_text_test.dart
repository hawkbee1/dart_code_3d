import 'package:dart_code_3d/l10n/gen/app_localizations_en.dart';
import 'package:dart_code_3d/l10n/gen/app_localizations_fr.dart';
import 'package:dart_code_3d/settings/widgets/rule_texts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_repository/settings_repository.dart';

void main() {
  group('ruleValueText', () {
    final en = AppLocalizationsEn();
    final fr = AppLocalizationsFr();

    RuleParameter<Object> rule(String id) =>
        RuleCatalog.all.firstWhere((r) => r.id == id);

    test('says On and Off for a switch', () {
      final rule = RuleCatalog.all.whereType<BoolParameter>().first;

      expect(en.ruleValueText(rule, true), 'On');
      expect(en.ruleValueText(rule, false), 'Off');
      expect(fr.ruleValueText(rule, false), 'Désactivé');
    });

    test('says the title of the chosen option', () {
      final calls = rule(RuleIds.ambiguousCalls);

      expect(en.ruleValueText(calls, 'skip'), 'Drop them');
      expect(fr.ruleValueText(calls, 'all'), isNot('all'));
    });

    test('keeps the raw value of an option it does not know', () {
      expect(en.ruleValueText(rule(RuleIds.ambiguousCalls), 'other'), 'other');
    });

    test('lists the chosen options of a set', () {
      final kinds = rule(RuleIds.memberKinds);

      expect(en.ruleValueText(kinds, {'method', 'getter'}), 'Methods, Getters');
    });

    test('says None for an empty set', () {
      expect(en.ruleValueText(rule(RuleIds.memberKinds), <String>{}), 'None');
    });

    test('counts the patterns of a list', () {
      final patterns = rule(RuleIds.generatedPatterns);

      expect(en.ruleValueText(patterns, const ['a', 'b']), '2 patterns');
      expect(en.ruleValueText(patterns, const ['a']), '1 pattern');
      expect(fr.ruleValueText(patterns, const ['a', 'b', 'c']), '3 motifs');
    });

    test('shows a text as it is', () {
      expect(
        en.ruleValueText(rule(RuleIds.entryPoint), 'lib/main_prod.dart'),
        'lib/main_prod.dart',
      );
    });
  });
}
