import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';

/// Keeps code maps as files in [directory]: `<id>.dc3d` for each map, and
/// `index.json` with what lists show (the summary and the project info), so
/// listing and sharing never decode a map.
///
/// Writes go through a temporary file and a rename, so an interrupted write
/// never leaves half a file, and operations run one after the other.
class FileCodeMapStore implements CodeMapStore {
  /// Creates a store in [directory] (created on the first save).
  new(this.directory);

  /// Where the files are.
  final Directory directory;

  static const _indexName = 'index.json';
  static const String _extension = CodeMapCodec.fileExtension;

  // Ids are made by the repository, but a stored index could be edited: an id
  // must never leave the directory.
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9._-]+$');

  Future<void> _last = Future<void>.value();

  File _fileOf(String id) => File('${directory.path}/$id.$_extension');

  File get _index => File('${directory.path}/$_indexName');

  @override
  Future<void> save(CodeMapFile file) => _exclusive(() async {
    if (!_safeId.hasMatch(file.id)) {
      throw ArgumentError.value(file.id, 'file.id', 'not a valid id');
    }
    await directory.create(recursive: true);
    await _write(_fileOf(file.id), file.bytes);
    final entries = await _readIndex();
    entries[file.id] = _Entry(file.summary, file.project);
    await _writeIndex(entries);
  });

  @override
  Future<List<CodeMapSummary>> list() => _exclusive(() async {
    final entries = await _readIndex();
    return [
      for (final entry in entries.values)
        // A file removed behind our back is not listed.
        if (_fileOf(entry.summary.id).existsSync()) entry.summary,
    ];
  });

  @override
  Future<CodeMapFile?> load(String id) => _exclusive(() async {
    if (!_safeId.hasMatch(id)) return null;
    final entry = (await _readIndex())[id];
    final file = _fileOf(id);
    if (entry == null || !file.existsSync()) return null;
    return CodeMapFile(
      id: id,
      name: entry.summary.name,
      bytes: await file.readAsBytes(),
      project: entry.project,
    );
  });

  @override
  Future<void> delete(String id) => _exclusive(() async {
    if (!_safeId.hasMatch(id)) return;
    final file = _fileOf(id);
    if (file.existsSync()) await file.delete();
    final entries = await _readIndex();
    if (entries.remove(id) != null) await _writeIndex(entries);
  });

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _last.then((_) => action());
    // The next operation waits, and runs even when this one failed.
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, _Entry>> _readIndex() async {
    final index = _index;
    if (!index.existsSync()) return {};
    try {
      final json = jsonDecode(await index.readAsString());
      final maps = (json as Map<String, Object?>)['maps']! as List<Object?>;
      final entries = [
        for (final raw in maps) _Entry.fromJson(raw! as Map<String, Object?>),
      ];
      return {for (final entry in entries) entry.summary.id: entry};
    } on Object {
      // A damaged index is a lost list, not a crash: the next save rewrites it.
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, _Entry> entries) => _write(
    _index,
    utf8.encode(
      jsonEncode({
        'version': 1,
        'maps': [for (final entry in entries.values) entry.toJson()],
      }),
    ),
  );

  Future<void> _write(File target, List<int> bytes) async {
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  }
}

class _Entry {
  const new(this.summary, this.project);

  factory fromJson(Map<String, Object?> json) => _Entry(
    CodeMapSummary.fromJson(json['summary']! as Map<String, Object?>),
    ProjectInfo.fromJson(json['project']! as Map<String, Object?>),
  );

  final CodeMapSummary summary;
  final ProjectInfo project;

  Map<String, Object?> toJson() => {
    'summary': summary.toJson(),
    'project': project.toJson(),
  };
}
