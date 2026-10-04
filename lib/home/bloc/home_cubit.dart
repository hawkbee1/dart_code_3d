import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:equatable/equatable.dart';

part 'home_state.dart';

/// The stored maps on the home screen: lists them, deletes (with undo),
/// opens a file and exports a map. It reloads whenever a map is saved or
/// deleted, wherever that happened.
class HomeCubit extends Cubit<HomeState> {
  /// Creates the cubit over the repository, the dialogs and the exporter;
  /// `exportMode` says how a map leaves the app.
  new({
    required this._repository,
    required this._dialogs,
    required this._exporter,
    required this._exportMode,
  }) : super(const HomeState()) {
    _changes = _repository.changes.listen((_) => unawaited(_reload()));
  }

  final CodeMapRepository _repository;
  final FileDialogs _dialogs;
  final FileExporter _exporter;
  final ExportMode _exportMode;

  late final StreamSubscription<void> _changes;
  var _serial = 0;

  /// Loads the stored maps (the home screen calls it once).
  Future<void> started() => _reload();

  /// Deletes the map [id] and offers to undo it.
  Future<void> deleted(String id) async {
    try {
      final file = await _repository.load(id);
      await _repository.delete(id);
      if (file != null) {
        emit(state.copyWith(notice: HomeMapDeleted(file, serial: ++_serial)));
      }
    } on BuildFailure catch (failure) {
      emit(state.copyWith(notice: HomeFailed(failure, serial: ++_serial)));
    }
  }

  /// Puts back a map deleted a moment ago.
  Future<void> deletionUndone(CodeMapFile file) async {
    try {
      await _repository.save(file);
    } on BuildFailure catch (failure) {
      emit(state.copyWith(notice: HomeFailed(failure, serial: ++_serial)));
    }
  }

  /// Asks for a `.dc3d` or `.fscene` file and stores it. Returns the id of
  /// the new map, or null when the user cancelled or the file is unusable
  /// (a [HomeFailed] notice says why).
  Future<String?> fileOpened() async {
    try {
      final picked = await _dialogs.pickCodeMap();
      if (picked == null) return null;
      final file = await _repository.importBytes(picked.name, picked.bytes);
      await _repository.save(file);
      return file.id;
    } on BuildFailure catch (failure) {
      emit(state.copyWith(notice: HomeFailed(failure, serial: ++_serial)));
      return null;
    }
  }

  /// Shares, saves or downloads the map [id], as the platform does it.
  Future<void> exported(String id) async {
    try {
      final file = await _repository.load(id);
      if (file == null) return;
      final export = _repository.exportForSharing(file);
      await _exporter.export(
        fileName: export.fileName,
        bytes: export.bytes,
        mode: _exportMode,
      );
    } on BuildFailure catch (failure) {
      emit(state.copyWith(notice: HomeFailed(failure, serial: ++_serial)));
    } on Object {
      // The share sheet or the save dialog failed: there is nothing to say
      // but that.
      emit(state.copyWith(notice: HomeExportFailed(serial: ++_serial)));
    }
  }

  Future<void> _reload() async {
    try {
      final maps = await _repository.recent();
      if (!isClosed) {
        emit(state.copyWith(status: HomeStatus.ready, maps: maps));
      }
    } on BuildFailure {
      if (!isClosed) emit(state.copyWith(status: HomeStatus.failure));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    await super.close();
  }
}
