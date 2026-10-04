import 'dart:convert';
import 'dart:io';

import 'package:dart_code_3d/app/storage/file_code_map_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(FileCodeMapStore, () {
    late Directory root;
    late Directory directory;
    late FileCodeMapStore store;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dc3d_store_');
      directory = Directory('${root.path}/code_maps');
      store = FileCodeMapStore(directory);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test(
      'is empty before anything is saved, even without its folder',
      () async {
        expect(directory.existsSync(), isFalse);

        expect(await store.list(), isEmpty);
        expect(await store.load('1-a'), isNull);
      },
    );

    test('saves a map and lists and loads it back', () async {
      final file = codeMapFileOf();

      await store.save(file);

      expect(await store.list(), [file.summary]);
      expect(await store.load(file.id), file);
    });

    test('keeps the maps after a restart', () async {
      final file = codeMapFileOf();
      await store.save(file);

      final restarted = FileCodeMapStore(directory);

      expect(await restarted.list(), [file.summary]);
      expect(await restarted.load(file.id), file);
    });

    test('replaces a map saved again under the same id', () async {
      await store.save(codeMapFileOf(name: 'first'));
      await store.save(codeMapFileOf(name: 'second'));

      final summaries = await store.list();

      expect(summaries.map((s) => s.name), ['second']);
      expect((await store.load('1-a'))!.name, 'second');
    });

    test('keeps maps apart', () async {
      final a = codeMapFileOf();
      final b = codeMapFileOf(id: '2-b', name: 'other', map: nestedMap());
      await store.save(a);
      await store.save(b);

      expect(
        (await store.list()).map((s) => s.id),
        unorderedEquals(['1-a', '2-b']),
      );
      expect(await store.load('2-b'), b);
      expect(await store.load('1-a'), a);
    });

    test('deletes a map and its file', () async {
      await store.save(codeMapFileOf());
      await store.save(codeMapFileOf(id: '2-b'));

      await store.delete('1-a');

      expect((await store.list()).map((s) => s.id), ['2-b']);
      expect(await store.load('1-a'), isNull);
      expect(File('${directory.path}/1-a.dc3d').existsSync(), isFalse);
    });

    test('ignores the deletion of a map that does not exist', () async {
      await store.save(codeMapFileOf());

      await store.delete('nope');

      expect(await store.list(), hasLength(1));
    });

    test('does not list a map whose file was removed', () async {
      await store.save(codeMapFileOf());
      File('${directory.path}/1-a.dc3d').deleteSync();

      expect(await store.list(), isEmpty);
      expect(await store.load('1-a'), isNull);
    });

    test('starts again from a damaged index', () async {
      await store.save(codeMapFileOf());
      File('${directory.path}/index.json').writeAsStringSync('{ not json');

      expect(await store.list(), isEmpty);

      await store.save(codeMapFileOf(id: '2-b'));
      expect((await store.list()).map((s) => s.id), ['2-b']);
    });

    test('leaves no temporary file behind', () async {
      await store.save(codeMapFileOf());
      await store.save(codeMapFileOf(id: '2-b'));
      await store.delete('1-a');

      final names = directory.listSync().map((e) => e.uri.pathSegments.last);

      expect(names, unorderedEquals(['2-b.dc3d', 'index.json']));
    });

    test('writes a readable index', () async {
      await store.save(codeMapFileOf());

      final json = jsonDecode(
        File('${directory.path}/index.json').readAsStringSync(),
      ) as Map<String, Object?>;

      expect(json['version'], 1);
      expect(json['maps'], hasLength(1));
    });

    test('saves maps one after the other when asked at once', () async {
      await Future.wait([
        for (var i = 0; i < 12; i++) store.save(codeMapFileOf(id: '$i-x')),
      ]);

      expect(await store.list(), hasLength(12));
    });

    group('ids that would leave the folder', () {
      test('are refused when saving', () {
        expect(
          () => store.save(codeMapFileOf(id: '../escape')),
          throwsArgumentError,
        );
        expect(root.listSync().whereType<File>(), isEmpty);
      });

      test('load nothing and delete nothing', () async {
        final outside = File('${root.path}/outside.dc3d')
          ..writeAsBytesSync([1, 2, 3]);

        expect(await store.load('../outside'), isNull);
        await store.delete('../outside');

        expect(outside.existsSync(), isTrue);
      });

      test('do not stop the next operation', () async {
        await expectLater(
          store.save(codeMapFileOf(id: 'a/b')),
          throwsArgumentError,
        );

        await store.save(codeMapFileOf());

        expect(await store.list(), hasLength(1));
      });
    });
  });
}
