import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/bloc/settings_bloc.dart';
import 'package:dart_code_3d/settings/widgets/rule_editor.dart';
import 'package:dart_code_3d/settings/widgets/rule_texts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

/// The settings screen. Its [SettingsBloc] is provided above the app.
class SettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const SettingsView();
}

class SettingsView extends StatelessWidget {
  const new({super.key, this.catalog = RuleCatalog.all});

  /// The rules shown: injectable to prove that a new rule needs no UI code.
  final List<RuleParameter<Object>> catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final state = context.watch<SettingsBloc>().state;
    final bloc = context.read<SettingsBloc>();
    final textTheme = Theme.of(context).textTheme;

    Widget header(String text) => Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.lg,
        spacing.md,
        spacing.sm,
      ),
      child: Text(text, style: textTheme.titleLarge),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: EdgeInsets.only(bottom: spacing.xl),
            children: [
              header(l10n.settingsAppearance),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: _ThemeModePicker(
                  selected: state.themeMode,
                  onChanged: (mode) => bloc.add(SettingsThemeModeChanged(mode)),
                ),
              ),
              header(l10n.settingsViewer),
              ListTile(
                title: Text(l10n.settingsTouchControls),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: spacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsTouchControlsHint),
                      SizedBox(height: spacing.sm),
                      Wrap(
                        spacing: spacing.sm,
                        runSpacing: spacing.xs,
                        children: [
                          for (final (mode, label) in [
                            (TouchControlsMode.auto, l10n.settingsTouchAuto),
                            (
                              TouchControlsMode.always,
                              l10n.settingsTouchAlways,
                            ),
                            (TouchControlsMode.never, l10n.settingsTouchNever),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: state.touchControls == mode,
                              onSelected: (_) =>
                                  bloc.add(SettingsTouchControlsChanged(mode)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              header(l10n.settingsRules),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: Text(
                  l10n.settingsRulesHint,
                  style: textTheme.bodyMedium,
                ),
              ),
              for (final group in RuleGroup.values) ...[
                if (catalog.any((r) => r.group == group))
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.md,
                      spacing.lg,
                      spacing.md,
                      spacing.xs,
                    ),
                    child: Text(
                      l10n.groupTitle(group),
                      style: textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                for (final rule in catalog.where((r) => r.group == group))
                  RuleEditor(
                    key: ValueKey(rule.id),
                    rule: rule,
                    value: state.rules[rule.id],
                    onChanged: (value) =>
                        bloc.add(SettingsRuleChanged(rule.id, value)),
                  ),
              ],
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.settingsResetRules),
                    onPressed: () => _confirmReset(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<SettingsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsResetTitle),
        content: Text(l10n.settingsResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsReset),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const SettingsRulesReset());
  }
}

/// Picks the theme: a segmented button, or wrapping chips when large text
/// would not fit in three segments.
class _ThemeModePicker extends StatelessWidget {
  const new({required this.selected, required this.onChanged});

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modes = [
      (AppThemeMode.system, Icons.brightness_auto, l10n.settingsThemeSystem),
      (AppThemeMode.light, Icons.light_mode, l10n.settingsThemeLight),
      (AppThemeMode.dark, Icons.dark_mode, l10n.settingsThemeDark),
    ];
    if (MediaQuery.textScalerOf(context).scale(1) > 1.5) {
      return Wrap(
        spacing: context.spacing.sm,
        runSpacing: context.spacing.xs,
        children: [
          for (final (mode, icon, label) in modes)
            ChoiceChip(
              avatar: Icon(icon),
              showCheckmark: false,
              label: Text(label),
              selected: mode == selected,
              onSelected: (_) => onChanged(mode),
            ),
        ],
      );
    }
    return SegmentedButton<AppThemeMode>(
      segments: [
        for (final (mode, icon, label) in modes)
          ButtonSegment(value: mode, icon: Icon(icon), label: Text(label)),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}
