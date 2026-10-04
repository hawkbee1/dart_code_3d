import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:dart_code_3d/analysis/cubit/source_form_cubit.dart';
import 'package:dart_code_3d/analysis/widgets/middle_ellipsis_text.dart';
import 'package:dart_code_3d/analysis/widgets/rules_summary.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart'
    show AnalysisRules;

/// The form of the new analysis: what to analyze, the rules in force and the
/// button that starts. [gitUnavailable] explains why the git option is
/// missing on this platform.
class SourceForm extends StatefulWidget {
  const new({
    required this.onEditRules,
    super.key,
    this.gitUnavailable = false,
  });

  /// Called when the user asks to edit the rules.
  final VoidCallback onEditRules;

  /// Whether to say that git repositories cannot be used here.
  final bool gitUnavailable;

  @override
  State<SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<SourceForm> {
  late final TextEditingController _url;
  late final TextEditingController _ref;

  @override
  void initState() {
    super.initState();
    // From the cubit's state: the form comes back filled in after a failure
    // or a cancellation.
    final form = context.read<SourceFormCubit>().state;
    _url = TextEditingController(text: form.gitUrl);
    _ref = TextEditingController(text: form.gitRef);
  }

  @override
  void dispose() {
    _url.dispose();
    _ref.dispose();
    super.dispose();
  }

  void _analyze(BuildContext context, SourceFormState form) {
    final source = form.source;
    if (source == null) return;
    context.read<AnalysisBloc>().add(
      AnalysisStarted(source, context.read<SettingsBloc>().state.rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final cubit = context.read<SourceFormCubit>();
    final rules = context.select<SettingsBloc, AnalysisRules>(
      (bloc) => bloc.state.rules,
    );
    return BlocBuilder<SourceFormCubit, SourceFormState>(
      builder: (context, form) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.analysisIntro, style: theme.textTheme.titleMedium),
          SizedBox(height: spacing.md),
          if (widget.gitUnavailable) ...[
            _NoGitNote(),
            SizedBox(height: spacing.md),
          ],
          if (form.kinds.length > 1) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                // Three long labels do not fit side by side on a phone.
                final narrow = constraints.maxWidth < 480;
                return SegmentedButton<SourceKind>(
                  showSelectedIcon: false,
                  segments: [
                    for (final kind in form.kinds)
                      ButtonSegment(
                        value: kind,
                        icon: narrow
                            ? null
                            : Icon(switch (kind) {
                                SourceKind.git => Icons.cloud_download_outlined,
                                SourceKind.folder => Icons.folder_open,
                                SourceKind.zip => Icons.folder_zip_outlined,
                              }),
                        label: Text(switch ((kind, narrow)) {
                          (SourceKind.git, false) => l10n.analysisSourceGit,
                          (SourceKind.folder, false) =>
                            l10n.analysisSourceFolder,
                          (SourceKind.zip, false) => l10n.analysisSourceZip,
                          (SourceKind.git, true) => l10n.analysisSourceGitShort,
                          (SourceKind.folder, true) =>
                            l10n.analysisSourceFolderShort,
                          (SourceKind.zip, true) => l10n.analysisSourceZipShort,
                        }),
                      ),
                  ],
                  selected: {form.kind},
                  onSelectionChanged: (kinds) =>
                      cubit.kindChanged(kinds.single),
                );
              },
            ),
            SizedBox(height: spacing.md),
          ],
          switch (form.kind) {
            SourceKind.git => _GitFields(
              form: form,
              url: _url,
              ref: _ref,
              onChanged: cubit.urlChanged,
              onRefChanged: cubit.refChanged,
              onSubmitted: () => _analyze(context, form),
            ),
            SourceKind.folder => _PickerRow(
              icon: Icons.folder_open,
              chosen: form.folderPath,
              none: l10n.analysisFolderNone,
              choose: l10n.analysisFolderChoose,
              change: l10n.analysisFolderChange,
              onPressed: cubit.folderPicked,
            ),
            SourceKind.zip => _PickerRow(
              icon: Icons.folder_zip_outlined,
              chosen: form.zip?.name,
              none: l10n.analysisZipNone,
              choose: l10n.analysisZipChoose,
              change: l10n.analysisZipChange,
              onPressed: cubit.zipPicked,
            ),
          },
          SizedBox(height: spacing.lg),
          RulesSummary(rules: rules, onEdit: widget.onEditRules),
          SizedBox(height: spacing.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.analysisAnalyze),
              onPressed: form.source == null
                  ? null
                  : () => _analyze(context, form),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGitNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(spacing.sm),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analysisNoGitTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    l10n.analysisNoGitBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GitFields extends StatelessWidget {
  const new({
    required this.form,
    required this.url,
    required this.ref,
    required this.onChanged,
    required this.onRefChanged,
    required this.onSubmitted,
  });

  final SourceFormState form;
  final TextEditingController url;
  final TextEditingController ref;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onRefChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.link),
            labelText: l10n.analysisGitUrlLabel,
            hintText: l10n.analysisGitUrlHint,
            errorText: form.urlInvalid ? l10n.analysisGitUrlError : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: onChanged,
        ),
        SizedBox(height: spacing.md),
        TextField(
          controller: ref,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.call_split),
            labelText: l10n.analysisGitRefLabel,
            hintText: l10n.analysisGitRefHint,
            helperText: l10n.analysisGitPublicOnly,
            border: const OutlineInputBorder(),
          ),
          onChanged: onRefChanged,
          onSubmitted: (_) => onSubmitted(),
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.chosen,
    required this.none,
    required this.choose,
    required this.change,
    required this.onPressed,
  });

  final IconData icon;
  final String? chosen;
  final String none;
  final String choose;
  final String change;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final chosen = this.chosen;
    return Row(
      children: [
        OutlinedButton.icon(
          icon: Icon(icon),
          label: Text(chosen == null ? choose : change),
          onPressed: onPressed,
        ),
        SizedBox(width: spacing.md),
        Expanded(
          child: chosen == null
              ? Text(
                  none,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : MiddleEllipsisText(chosen, style: theme.textTheme.bodyLarge),
        ),
      ],
    );
  }
}
