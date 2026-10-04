import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/models/changed_rules.dart';
import 'package:dart_code_3d/settings/widgets/rule_texts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

/// Which rules the analysis will use: the defaults, or the rules the user
/// changed (highlighted), with a way to edit them.
class RulesSummary extends StatelessWidget {
  const new({required this.rules, required this.onEdit, super.key});

  /// The rules in force.
  final AnalysisRules rules;

  /// Called when the user asks to edit the rules.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final changed = changedRules(rules);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: theme.colorScheme.primary),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    l10n.analysisRulesTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.analysisRulesEdit),
                  onPressed: onEdit,
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Text(
              changed.isEmpty
                  ? l10n.analysisRulesDefault
                  : l10n.analysisRulesChanged(changed.length),
              style: theme.textTheme.bodyMedium,
            ),
            if (changed.isNotEmpty) ...[
              SizedBox(height: spacing.sm),
              Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  for (final rule in changed)
                    Chip(
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                      side: BorderSide.none,
                      label: Text(
                        l10n.analysisRuleChip(
                          l10n.ruleTitle(rule),
                          l10n.ruleValueText(rule, rules[rule.id]),
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
