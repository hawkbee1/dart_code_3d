import 'dart:io';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/storage/file_code_map_store.dart';
import 'package:path_provider/path_provider.dart';

/// The store of native platforms: files in the application support
/// directory ([supportDirectory] is injectable for tests).
Future<CodeMapStore> createCodeMapStore({
  Future<Directory> Function()? supportDirectory,
}) async {
  final base = await (supportDirectory ?? getApplicationSupportDirectory)();
  return FileCodeMapStore(Directory('${base.path}/code_maps'));
}
