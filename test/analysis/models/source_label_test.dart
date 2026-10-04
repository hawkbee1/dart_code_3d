import 'dart:typed_data';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/models/source_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(sourceLabel, () {
    test('names a repository', () {
      expect(
        sourceLabel(
          const GitRepositorySource('https://github.com/TalaoDAO/AltMe.git'),
        ),
        'AltMe',
      );
    });

    test('keeps what was typed when it is not a known repository', () {
      expect(
        sourceLabel(const GitRepositorySource(' https://example.com/x ')),
        'https://example.com/x',
      );
    });

    test('names a folder by its last segment', () {
      expect(sourceLabel(const LocalFolderSource('/home/dev/AltMe/')), 'AltMe');
      expect(sourceLabel(const LocalFolderSource(r'C:\code\AltMe')), 'AltMe');
    });

    test('keeps the path of the root folder', () {
      expect(sourceLabel(const LocalFolderSource('/')), '/');
    });

    test('names a zip by its file', () {
      expect(
        sourceLabel(ZipBytesSource(fileName: 'app.zip', bytes: Uint8List(0))),
        'app.zip',
      );
    });
  });
}
