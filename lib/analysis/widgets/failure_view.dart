import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/widgets/failure_style.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Says why an analysis failed, with what can be done about it.
class FailureView extends StatelessWidget {
  const new({
    required this.failure,
    required this.onChangeSource,
    required this.onRetry,
    super.key,
  });

  /// What went wrong.
  final BuildFailure failure;

  /// Called to go back to the form.
  final VoidCallback onChangeSource;

  /// Called to try again; null when trying again cannot help.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final details = failure.details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(failure.kind.icon, size: 64, color: theme.colorScheme.error),
        SizedBox(height: spacing.md),
        // A live region: a screen reader says the failure when it appears.
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l10n.failureTitle(failure.kind),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          l10n.failureBody(failure.kind),
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (details != null) ...[
          SizedBox(height: spacing.md),
          Card.outlined(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text(l10n.analysisFailureDetails),
              shape: const Border(),
              collapsedShape: const Border(),
              childrenPadding: EdgeInsets.fromLTRB(
                spacing.md,
                0,
                spacing.md,
                spacing.md,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      details,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: spacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            if (onRetry != null)
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.analysisRetry),
                onPressed: onRetry,
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.analysisChangeSource),
              onPressed: onChangeSource,
            ),
          ],
        ),
      ],
    );
  }
}
