import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/viewer/models/code_map_source.dart';
import 'package:dart_code_3d/viewer/world/visibility.dart';
import 'package:equatable/equatable.dart';

part 'viewer_event.dart';
part 'viewer_state.dart';

/// Opens a code map and keeps what the viewer shows of it.
class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  /// Creates the bloc. `loadAsset` and `readFile` read the bytes of asset
  /// and local file sources.
  new({
    required this._repository,
    required this._loadAsset,
    required this._readFile,
  }) : super(const ViewerLoading()) {
    on<ViewerOpened>(_onOpened);
    on<ViewerContainerChanged>(
      (event, emit) => _update(
        emit,
        (s) => s.copyWith(currentContainerId: () => event.containerId),
      ),
    );
    on<ViewerNodeSelected>(
      (event, emit) => _update(
        emit,
        (s) => s.copyWith(
          selectedId: () => event.nodeId,
          // Focus ends with the selection.
          focusOnSelected: event.nodeId != null && s.focusOnSelected,
        ),
      ),
    );
    on<ViewerFocusToggled>(
      (event, emit) => _update(
        emit,
        (s) => s.selectedId == null
            ? s
            : s.copyWith(focusOnSelected: !s.focusOnSelected),
      ),
    );
    on<ViewerViewModeToggled>(
      (event, emit) => _update(
        emit,
        (s) => s.copyWith(
          viewMode: s.viewMode == ViewMode.interior
              ? ViewMode.window
              : ViewMode.interior,
        ),
      ),
    );
    on<ViewerLinkKindToggled>(
      (event, emit) => _update(
        emit,
        (s) => s.copyWith(
          visibleLinkKinds: s.visibleLinkKinds.contains(event.kind)
              ? ({...s.visibleLinkKinds}..remove(event.kind))
              : {...s.visibleLinkKinds, event.kind},
        ),
      ),
    );
    on<ViewerLabelsToggled>(
      (event, emit) => _update(emit, (s) => s.copyWith(labelsOn: !s.labelsOn)),
    );
  }

  final CodeMapRepository _repository;
  final Future<ByteData> Function(String key) _loadAsset;
  final Future<Uint8List> Function(String path) _readFile;

  Future<void> _onOpened(ViewerOpened event, Emitter<ViewerState> emit) async {
    if (state is! ViewerLoading) emit(const ViewerLoading());
    try {
      final bytes = switch (event.source) {
        AssetCodeMapSource(:final path) => Uint8List.sublistView(
          await _loadAsset(path),
        ),
        BytesCodeMapSource(:final bytes) => bytes,
        LocalFileCodeMapSource(:final path) => await _readFile(path),
        StoredCodeMapSource(:final id) => (await _repository.load(id))?.bytes,
      };
      if (bytes == null) {
        emit(const ViewerFailure('', kind: ViewerFailureKind.missing));
        return;
      }
      emit(ViewerReady(map: await _repository.openBytes(bytes)));
    } on BuildFailure catch (failure) {
      emit(ViewerFailure(failure.message));
    } on Object catch (error) {
      emit(ViewerFailure('$error'));
    }
  }

  void _update(
    Emitter<ViewerState> emit,
    ViewerReady Function(ViewerReady state) change,
  ) {
    if (state case final ViewerReady ready) emit(change(ready));
  }
}
