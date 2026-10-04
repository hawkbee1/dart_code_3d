part of 'analysis_bloc.dart';

/// Something the user did on the analysis screen.
sealed class AnalysisEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The user started analyzing [source] with [rules].
final class AnalysisStarted extends AnalysisEvent {
  const new(this.source, this.rules);

  final CodeSource source;
  final AnalysisRules rules;

  @override
  List<Object?> get props => [source, rules];
}

/// The user asked to try the last analysis again.
final class AnalysisRetried extends AnalysisEvent {
  const new();
}

/// The user cancelled the running analysis.
final class AnalysisCancelled extends AnalysisEvent {
  const new();
}

/// The user left a failure to change the source.
final class AnalysisDismissed extends AnalysisEvent {
  const new();
}
