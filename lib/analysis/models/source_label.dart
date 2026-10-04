import 'package:code_map_repository/code_map_repository.dart';

/// A short name for [source], shown while it is analyzed: the repository,
/// the folder or the zip file.
String sourceLabel(CodeSource source) => switch (source) {
  GitRepositorySource(:final url) => GitUrl.tryParse(url)?.name ?? url.trim(),
  LocalFolderSource(:final path) => _lastSegment(path),
  ZipBytesSource(:final fileName) => fileName,
};

String _lastSegment(String path) {
  final segments = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty);
  return segments.isEmpty ? path : segments.last;
}
