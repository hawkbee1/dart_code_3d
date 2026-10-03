import 'dart:io';
import 'dart:typed_data';

import 'package:dart_code_3d/viewer/models/local_file.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CodeMapSource, () {
    test('sources compare by value', () {
      final bytes = Uint8List.fromList([1]);
      expect(
        CodeMapSource.sample,
        const AssetCodeMapSource('assets/samples/sample.dc3d'),
      );
      expect(BytesCodeMapSource('a', bytes), BytesCodeMapSource('a', bytes));
      expect(const LocalFileCodeMapSource('/a').props, ['/a']);
      // Not const: equal const instances are identical, so props never run.
      // ignore: prefer_const_constructors
      expect(AssetCodeMapSource('a').props, ['a']);
    });

    test('the sample asset exists', () {
      expect(File(CodeMapSource.sample.path).existsSync(), isTrue);
    });
  });

  group('readLocalFile', () {
    test('reads a file by path', () async {
      final dir = Directory.systemTemp.createTempSync('dc3d');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/m.dc3d')..writeAsBytesSync([4, 2]);

      expect(await readLocalFile(file.path), [4, 2]);
    });
  });
}
