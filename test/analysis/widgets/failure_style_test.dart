import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/widgets/failure_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FailureKindStyle', () {
    test('offers to try again when it may work', () {
      expect(
        BuildFailureKind.values.where((kind) => kind.retryable),
        unorderedEquals([
          BuildFailureKind.network,
          BuildFailureKind.rateLimited,
          BuildFailureKind.storage,
          BuildFailureKind.analysisError,
        ]),
      );
    });

    test('has an icon for every kind', () {
      for (final kind in BuildFailureKind.values) {
        expect(kind.icon, isNotNull);
      }
    });
  });
}
