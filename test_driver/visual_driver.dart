// Host side of the 3D visual tests. Writes each capture to
// build/visual/<scenario>/<variant>.png, then compares it with
// visual_baselines/<scenario>/<variant>.png. With VISUAL_UPDATE=1 the
// captures replace the baselines instead.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'image_compare.dart';

Future<void> main() => integrationDriver(
  // Write the captures even when a sanity check failed: that is when they
  // are most useful to look at.
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final captures = (data?['captures'] as Map<String, dynamic>?) ?? {};
    final update = Platform.environment['VISUAL_UPDATE'] == '1';
    final failures = <String>[];

    for (final MapEntry(key: name, value: encoded) in captures.entries) {
      final bytes = base64Decode(encoded as String);
      File('build/visual/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      final baseline = File('visual_baselines/$name');
      if (update) {
        baseline
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        stdout.writeln('UPDATED $name');
        continue;
      }
      if (!baseline.existsSync()) {
        failures.add('$name: no baseline (run tool/visual_test.sh --update)');
        continue;
      }
      final result = compareImages(bytes, baseline.readAsBytesSync());
      stdout.writeln(
        '${result.passed ? 'OK  ' : 'FAIL'} $name: ${result.message}',
      );
      if (!result.passed) {
        failures.add('$name: ${result.message}');
        if (result.diffPng != null) {
          File('build/visual/${name.replaceAll('.png', '_diff.png')}')
              .writeAsBytesSync(result.diffPng!);
        }
      }
    }

    if (captures.isEmpty) failures.add('no capture received');
    if (failures.isNotEmpty) {
      stderr.writeln('Visual differences:\n  ${failures.join('\n  ')}');
      // integrationDriver exits 0 after this callback, so fail here.
      exit(1);
    }
  },
);
