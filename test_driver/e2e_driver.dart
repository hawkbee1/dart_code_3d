// Host side of the end-to-end test: writes the viewer capture to
// build/e2e/viewer.png and the measurements to build/e2e/report.json.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final report = {...?data};
    final captures = (report.remove('captures') as Map<String, dynamic>?) ?? {};
    Directory('build/e2e').createSync(recursive: true);
    for (final MapEntry(key: name, value: encoded) in captures.entries) {
      File('build/e2e/$name').writeAsBytesSync(base64Decode(encoded as String));
    }
    File('build/e2e/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  },
);
