// Host side of the end-to-end test: writes the viewer capture to
// build/e2e/viewer-<repo>.png and the measurements to
// build/e2e/report-<repo>.json.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final report = {...?data};
    final captures = (report.remove('captures') as Map<String, dynamic>?) ?? {};
    // One file per repository: `viewer-AltMe.png`, `report-AltMe.json`.
    final slug = Uri.parse('${report['url']}').pathSegments.last;
    Directory('build/e2e').createSync(recursive: true);
    for (final MapEntry(key: name, value: encoded) in captures.entries) {
      final dot = name.lastIndexOf('.');
      File('build/e2e/${name.substring(0, dot)}-$slug${name.substring(dot)}')
          .writeAsBytesSync(base64Decode(encoded as String));
    }
    File('build/e2e/report-$slug.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  },
);
