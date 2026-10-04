import 'dart:convert';

import 'package:settings_repository/settings_repository.dart';

/// The rules of [rules] whose value is not the default, in display order.
List<RuleParameter<Object>> changedRules(AnalysisRules rules) {
  final defaults = AnalysisRules.defaults(catalog: rules.catalog).toJson();
  final current = rules.toJson();
  return [
    for (final rule in rules.catalog)
      // Compared as JSON: values are lists and sets, and the JSON of a
      // set is in a fixed order.
      if (jsonEncode(current[rule.id]) != jsonEncode(defaults[rule.id])) rule,
  ];
}
