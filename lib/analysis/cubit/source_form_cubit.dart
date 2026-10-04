import 'package:bloc/bloc.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:equatable/equatable.dart';

part 'source_form_state.dart';

/// The form that picks what to analyze: a git repository, a folder or a zip.
class SourceFormCubit extends Cubit<SourceFormState> {
  /// Creates the form offering `kinds` (the first is selected); the dialogs
  /// pick folders and files.
  new({required this._dialogs, required List<SourceKind> kinds})
    : assert(kinds.isNotEmpty, 'at least one source kind is needed'),
      super(SourceFormState(kinds: kinds, kind: kinds.first));

  final FileDialogs _dialogs;

  /// The user chose another kind of source.
  void kindChanged(SourceKind kind) {
    if (state.kinds.contains(kind)) emit(state.copyWith(kind: kind));
  }

  /// The user typed the repository URL.
  void urlChanged(String url) => emit(state.copyWith(gitUrl: url));

  /// The user typed the branch or tag.
  void refChanged(String ref) => emit(state.copyWith(gitRef: ref));

  /// The user asked to pick a folder.
  Future<void> folderPicked() async {
    final path = await _dialogs.pickFolder();
    if (path != null) emit(state.copyWith(folderPath: () => path));
  }

  /// The user asked to pick a zip file.
  Future<void> zipPicked() async {
    final zip = await _dialogs.pickZip();
    if (zip != null) emit(state.copyWith(zip: () => zip));
  }
}
