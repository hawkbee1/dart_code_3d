part of 'analysis_bloc.dart';

/// What the analysis screen shows.
sealed class AnalysisState extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Nothing is running: the form is shown.
final class AnalysisIdle extends AnalysisState {
  const new();
}

/// An analysis is running.
final class AnalysisRunning extends AnalysisState {
  const new({
    required this.label,
    required this.stage,
    required this.fraction,
    this.detail,
  });

  /// What is analyzed (a repository, folder or file name).
  final String label;

  /// What it is doing.
  final BuildStage stage;

  /// Overall progress, 0 to 1.
  final double fraction;

  /// The file being handled, if any.
  final String? detail;

  @override
  List<Object?> get props => [label, stage, fraction, detail];
}

/// The analysis failed.
final class AnalysisFailed extends AnalysisState {
  const new(this.failure);

  final BuildFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// The map is built and saved as [mapId]: the viewer opens it.
final class AnalysisSucceeded extends AnalysisState {
  const new(this.mapId);

  final String mapId;

  @override
  List<Object?> get props => [mapId];
}
