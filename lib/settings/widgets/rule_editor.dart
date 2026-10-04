import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/widgets/rule_texts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

/// Edits one rule, choosing the control from the rule's type: the settings
/// screen renders the whole catalog generically.
class RuleEditor extends StatelessWidget {
  const new({
    required this.rule,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final RuleParameter<Object> rule;
  final Object value;
  final ValueChanged<Object> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parameter = rule;
    final title = l10n.ruleTitle(parameter);
    final description = l10n.ruleDescription(parameter);
    final control = switch (parameter) {
      BoolParameter() => null,
      EnumParameter(:final options) => _ChoiceControl(
        options: options,
        selected: {value as String},
        onTap: (option) => onChanged(option.value),
      ),
      EnumSetParameter(:final options) => _ChoiceControl(
        options: options,
        selected: (value as Set).cast<String>(),
        multiple: true,
        onTap: (option) {
          final current = (value as Set).cast<String>();
          onChanged(
            current.contains(option.value)
                ? ({...current}..remove(option.value))
                : {...current, option.value},
          );
        },
      ),
      GlobListParameter() => _GlobListControl(
        patterns: (value as List).cast<String>(),
        onChanged: onChanged,
      ),
      StringParameter() => _TextControl(
        value: value as String,
        onChanged: onChanged,
      ),
    };
    if (control == null) {
      return SwitchListTile(
        title: Text(title),
        subtitle: Text(description),
        value: value as bool,
        onChanged: onChanged,
      );
    }
    return ListTile(
      title: Text(title),
      subtitle: Padding(
        padding: EdgeInsets.only(top: context.spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            SizedBox(height: context.spacing.sm),
            control,
          ],
        ),
      ),
    );
  }
}

class _ChoiceControl extends StatelessWidget {
  const new({
    required this.options,
    required this.selected,
    required this.onTap,
    this.multiple = false,
  });

  final List<RuleOption> options;
  final Set<String> selected;
  final ValueChanged<RuleOption> onTap;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: context.spacing.sm,
      runSpacing: context.spacing.xs,
      children: [
        for (final option in options)
          Opacity(
            opacity: option.enabled ? 1 : 0.5,
            child: multiple
                ? FilterChip(
                    label: Text(l10n.optionTitle(option)),
                    selected: selected.contains(option.value),
                    onSelected: (_) => _tap(context, option),
                  )
                : ChoiceChip(
                    label: Text(l10n.optionTitle(option)),
                    selected: selected.contains(option.value),
                    onSelected: (_) => _tap(context, option),
                  ),
          ),
      ],
    );
  }

  void _tap(BuildContext context, RuleOption option) {
    if (option.enabled) {
      onTap(option);
      return;
    }
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsComingLaterTitle),
        content: Text(l10n.optionNote(option) ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.settingsOk),
          ),
        ],
      ),
    );
  }
}

class _GlobListControl extends StatefulWidget {
  const new({required this.patterns, required this.onChanged});

  final List<String> patterns;
  final ValueChanged<Object> onChanged;

  @override
  State<_GlobListControl> createState() => _GlobListControlState();
}

class _GlobListControlState extends State<_GlobListControl> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final pattern = _controller.text.trim();
    if (!GlobListParameter.isValidGlob(pattern)) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    _controller.clear();
    widget.onChanged([...widget.patterns, pattern]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.spacing.sm,
          runSpacing: context.spacing.xs,
          children: [
            for (final pattern in widget.patterns)
              InputChip(
                label: Text(pattern),
                onDeleted: () => widget.onChanged([
                  for (final p in widget.patterns)
                    if (p != pattern) p,
                ]),
              ),
          ],
        ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: l10n.settingsGlobHint,
            errorText: _invalid ? l10n.settingsGlobInvalid : null,
            suffixIcon: IconButton(
              tooltip: l10n.settingsGlobAdd,
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
          ),
          onSubmitted: (_) => _add(),
        ),
      ],
    );
  }
}

class _TextControl extends StatefulWidget {
  const new({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<Object> onChanged;

  @override
  State<_TextControl> createState() => _TextControlState();
}

class _TextControlState extends State<_TextControl> {
  late final _controller = TextEditingController(text: widget.value);
  bool _invalid = false;

  @override
  void didUpdateWidget(_TextControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        errorText: _invalid ? context.l10n.settingsTextInvalid : null,
      ),
      onSubmitted: (text) {
        final valid = text.trim().isNotEmpty;
        setState(() => _invalid = !valid);
        if (valid) widget.onChanged(text.trim());
      },
    );
  }
}
