import 'package:bloc/bloc.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/models/source_label.dart';
import 'package:equatable/equatable.dart';
import 'package:settings_repository/settings_repository.dart'
    show AnalysisRules;

part 'analysis_event.dart';
part 'analysis_state.dart';

/// Runs one analysis at a time: builds the map from a source, saves it, and
/// reports progress, failures and cancellation.
class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  /// Creates the bloc over the repository that builds and stores maps.
  new({required this._repository}) : super(const AnalysisIdle()) {
    on<AnalysisStarted>((event, emit) async {
      if (state is AnalysisRunning) return;
      await _run(event, emit);
    });
    on<AnalysisRetried>((event, emit) async {
      final last = _last;
      if (last == null || state is AnalysisRunning) return;
      await _run(last, emit);
    });
    on<AnalysisCancelled>((event, emit) {
      if (state is! AnalysisRunning) return;
      // Back to the form at once: layout cannot be interrupted and the build
      // finishes (and removes its temporary files) in the background.
      _cancel?.cancel();
      emit(const AnalysisIdle());
    });
    on<AnalysisDismissed>((event, emit) => emit(const AnalysisIdle()));
  }

  final CodeMapRepository _repository;

  AnalysisStarted? _last;
  CancelToken? _cancel;

  Future<void> _run(
    AnalysisStarted request,
    Emitter<AnalysisState> emit,
  ) async {
    _last = request;
    final token = _cancel = CancelToken();
    final label = sourceLabel(request.source);
    // False once the run was cancelled, or the bloc closed.
    bool active() => !isClosed && !token.isCancelled;

    emit(
      AnalysisRunning(label: label, stage: BuildStage.fetching, fraction: 0),
    );
    // Keep reading after a cancellation, so the build can clean up.
    await for (final event in _repository.build(
      request.source,
      request.rules,
      cancel: token,
    )) {
      if (!active()) continue;
      switch (event) {
        case BuildProgress(:final stage, :final fraction, :final detail):
          emit(
            AnalysisRunning(
              label: label,
              stage: stage,
              fraction: fraction,
              detail: detail,
            ),
          );
        case BuildSucceeded(:final file):
          emit(
            AnalysisRunning(
              label: label,
              stage: BuildStage.encoding,
              fraction: 1,
            ),
          );
          try {
            await _repository.save(file);
          } on BuildFailure catch (failure) {
            if (active()) emit(AnalysisFailed(failure));
            return;
          }
          if (active()) emit(AnalysisSucceeded(file.id));
        case BuildFailed(:final failure):
          emit(
            failure.kind == BuildFailureKind.cancelled
                ? const AnalysisIdle()
                : AnalysisFailed(failure),
          );
      }
    }
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
