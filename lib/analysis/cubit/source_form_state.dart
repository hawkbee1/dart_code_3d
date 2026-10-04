part of 'source_form_cubit.dart';

/// What can be analyzed.
enum SourceKind {
  /// A public GitHub or GitLab repository.
  git,

  /// A folder on this device.
  folder,

  /// A zip file.
  zip,
}

/// What the source form holds.
final class SourceFormState extends Equatable {
  /// Creates the state.
  const new({
    required this.kinds,
    required this.kind,
    this.gitUrl = '',
    this.gitRef = '',
    this.folderPath,
    this.zip,
  });

  /// The kinds this platform offers.
  final List<SourceKind> kinds;

  /// The selected kind.
  final SourceKind kind;

  /// The repository URL as typed.
  final String gitUrl;

  /// The branch or tag as typed (empty for the default branch).
  final String gitRef;

  /// The chosen folder.
  final String? folderPath;

  /// The chosen zip file.
  final PickedFile? zip;

  /// Whether a URL was typed that is not a GitHub or GitLab repository.
  bool get urlInvalid =>
      kind == SourceKind.git &&
      gitUrl.trim().isNotEmpty &&
      GitUrl.tryParse(gitUrl) == null;

  /// The source to analyze, or null while the form is incomplete or invalid.
  CodeSource? get source => switch (kind) {
    SourceKind.git =>
      GitUrl.tryParse(gitUrl) == null
          ? null
          : GitRepositorySource(
              gitUrl.trim(),
              ref: gitRef.trim().isEmpty ? null : gitRef.trim(),
            ),
    SourceKind.folder => switch (folderPath) {
      final path? => LocalFolderSource(path),
      null => null,
    },
    SourceKind.zip => switch (zip) {
      final file? => ZipBytesSource(fileName: file.name, bytes: file.bytes),
      null => null,
    },
  };

  /// A copy with changes; nullable fields are set through a callback so
  /// they can be cleared.
  SourceFormState copyWith({
    SourceKind? kind,
    String? gitUrl,
    String? gitRef,
    String? Function()? folderPath,
    PickedFile? Function()? zip,
  }) => SourceFormState(
    kinds: kinds,
    kind: kind ?? this.kind,
    gitUrl: gitUrl ?? this.gitUrl,
    gitRef: gitRef ?? this.gitRef,
    folderPath: folderPath == null ? this.folderPath : folderPath(),
    zip: zip == null ? this.zip : zip(),
  );

  @override
  List<Object?> get props => [kinds, kind, gitUrl, gitRef, folderPath, zip];
}
