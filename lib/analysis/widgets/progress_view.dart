import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:dart_code_3d/analysis/widgets/elapsed_clock.dart';
import 'package:dart_code_3d/analysis/widgets/middle_ellipsis_text.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The progress of a running analysis: the stages, a progress bar, the file
/// being read, the elapsed time and a cancel button.
class ProgressView extends StatelessWidget {
  const new({required this.state, required this.onCancel, super.key});

  /// What the analysis is doing.
  final AnalysisRunning state;

  /// Called when the user asks to cancel.
  final VoidCallback onCancel;

  static const List<BuildStage> _stages = [
    BuildStage.fetching,
    BuildStage.analyzing,
    BuildStage.layingOut,
    BuildStage.encoding,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final current = _stages.indexOf(state.stage);
    final calm = MediaQuery.disableAnimationsOf(context);
    // Layout cannot report its progress (it takes seconds on a big project
    // while the fraction stays put): show activity instead of a stuck bar.
    final working =
        state.stage == BuildStage.layingOut ||
        state.stage == BuildStage.encoding;
    final percent = (state.fraction * 100).round();
    String stageText(BuildStage stage) => switch (stage) {
      BuildStage.fetching => l10n.analysisStageFetching,
      BuildStage.analyzing => l10n.analysisStageAnalyzing,
      BuildStage.layingOut => l10n.analysisStageLayingOut,
      BuildStage.encoding => l10n.analysisStageSaving,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.analysisProgressTitle(state.label),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        SizedBox(height: spacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(spacing.xs),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: working && !calm ? null : state.fraction,
            semanticsLabel: stageText(state.stage),
            semanticsValue: l10n.analysisProgressSemantics(percent),
          ),
        ),
        SizedBox(height: spacing.xs),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text('$percent %', style: theme.textTheme.labelMedium),
        ),
        SizedBox(height: spacing.md),
        for (final (index, stage) in _stages.indexed)
          _StageRow(
            label: stageText(stage),
            status: index < current
                ? _StageStatus.done
                : index == current
                ? _StageStatus.active
                : _StageStatus.waiting,
            calm: calm,
          ),
        SizedBox(height: spacing.md),
        // Always as tall as one line, so the buttons do not jump.
        SizedBox(
          height: 24,
          child: state.stage == BuildStage.layingOut
              ? Text(
                  l10n.analysisLayingOutHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : state.detail == null
              ? null
              : MiddleEllipsisText(
                  state.detail!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            const Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ElapsedClock(),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: Text(l10n.analysisCancel),
              onPressed: onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

enum _StageStatus { done, active, waiting }

class _StageRow extends StatelessWidget {
  const new({required this.label, required this.status, required this.calm});

  final String label;
  final _StageStatus status;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final scheme = theme.colorScheme;
    final icon = switch (status) {
      _StageStatus.done => Icon(Icons.check_circle, color: scheme.primary),
      _StageStatus.active when calm => Icon(
        Icons.pending,
        color: scheme.primary,
      ),
      _StageStatus.active => const SizedBox.square(
        dimension: 20,
        child: Padding(
          padding: EdgeInsets.all(1),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      _StageStatus.waiting => Icon(
        Icons.radio_button_unchecked,
        color: scheme.outline,
      ),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        children: [
          SizedBox.square(dimension: 24, child: Center(child: icon)),
          SizedBox(width: spacing.md),
          Expanded(
            // The stage that starts is announced.
            child: Semantics(
              liveRegion: status == _StageStatus.active,
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: status == _StageStatus.waiting
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  fontWeight: status == _StageStatus.active
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
