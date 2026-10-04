import 'dart:io';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/storage/code_map_store_io.dart' as native;
import 'package:dart_code_3d/app/storage/code_map_store_web.dart' as web;
import 'package:dart_code_3d/app/storage/file_code_map_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('createCodeMapStore', () {
    test('keeps files in the support directory on native platforms', () async {
      final root = Directory.systemTemp.createTempSync('dc3d_support_');
      addTearDown(() => root.deleteSync(recursive: true));

      final store = await native.createCodeMapStore(
        supportDirectory: () async => root,
      );

      expect(store, isA<FileCodeMapStore>());
      expect(
        (store as FileCodeMapStore).directory.path,
        '${root.path}/code_maps',
      );
    });

    test('keeps maps in memory on the web', () async {
      expect(await web.createCodeMapStore(), isA<InMemoryCodeMapStore>());
    });
  });
}
