import 'dart:async';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:dart_code_3d/analysis/cubit/source_form_cubit.dart';
import 'package:dart_code_3d/analysis/widgets/cancel_analysis_dialog.dart';
import 'package:dart_code_3d/analysis/widgets/failure_style.dart';
import 'package:dart_code_3d/analysis/widgets/failure_view.dart';
import 'package:dart_code_3d/analysis/widgets/progress_view.dart';
import 'package:dart_code_3d/analysis/widgets/source_form.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Picks what to analyze, runs the analysis with its progress, and opens the
/// map in the viewer. Provides its own bloc and form.
class NewAnalysisPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final capabilities = context.read<PlatformCapabilities>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              AnalysisBloc(repository: context.read<CodeMapRepository>()),
        ),
        BlocProvider(
          create: (context) => SourceFormCubit(
            dialogs: context.read<FileDialogs>(),
            kinds: [
              if (capabilities.gitSources) SourceKind.git,
              if (capabilities.folderSources) SourceKind.folder,
              SourceKind.zip,
            ],
          ),
        ),
      ],
      child: NewAnalysisView(gitUnavailable: !capabilities.gitSources),
    );
  }
}

/// The screen of [NewAnalysisPage] over the blocs above it.
class NewAnalysisView extends StatelessWidget {
  const new({super.key, this.gitUnavailable = false});

  /// Whether to say that git repositories cannot be used on this platform.
  final bool gitUnavailable;

  Future<void> _confirmCancel(BuildContext context) async {
    final bloc = context.read<AnalysisBloc>();
    if (await CancelAnalysisDialog.show(context)) {
      bloc.add(const AnalysisCancelled());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return BlocConsumer<AnalysisBloc, AnalysisState>(
      listenWhen: (previous, current) => current is AnalysisSucceeded,
      listener: (context, state) {
        if (state is AnalysisSucceeded) {
          ViewerRoute(id: state.mapId).go(context);
        }
      },
      builder: (context, state) => PopScope(
        // Leaving a running analysis asks first.
        canPop: state is! AnalysisRunning,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_confirmCancel(context));
        },
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.newAnalysisTitle)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(spacing.lg),
                child: switch (state) {
                  AnalysisIdle() => SourceForm(
                    gitUnavailable: gitUnavailable,
                    // The form stays under the settings, filled in.
                    onEditRules: () =>
                        const SettingsRoute().push<void>(context),
                  ),
                  final AnalysisRunning running => ProgressView(
                    state: running,
                    onCancel: () => unawaited(_confirmCancel(context)),
                  ),
                  AnalysisFailed(:final failure) => FailureView(
                    failure: failure,
                    onChangeSource: () => context.read<AnalysisBloc>().add(
                      const AnalysisDismissed(),
                    ),
                    onRetry: failure.kind.retryable
                        ? () => context.read<AnalysisBloc>().add(
                            const AnalysisRetried(),
                          )
                        : null,
                  ),
                  // The viewer opens next.
                  AnalysisSucceeded() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
