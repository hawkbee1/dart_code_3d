import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes the performance report to build/perf/report.json.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    File('build/perf/report.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(data?['perf']),
      );
  },
);
