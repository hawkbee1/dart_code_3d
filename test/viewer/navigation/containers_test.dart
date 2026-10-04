import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group('findContainer', () {
    late CodeMap map;
    late Map<String, Vector3> positions;

    setUp(() {
      map = worldMap();
      positions = worldPositions(map);
    });

    test('is the world outside every sphere', () {
      expect(findContainer(Vector3(0, 50, 0), map, positions), isNull);
    });

    test('finds the deepest sphere containing the point', () {
      expect(findContainer(Vector3(3, 0, 0), map, positions), 'A');
      expect(findContainer(Vector3(5, 0.1, 0), map, positions), 'A.m');
    });

    test('never enters external package spheres', () {
      expect(findContainer(Vector3(-20, 0, 0), map, positions), isNull);
    });

    test('enters ghost parents', () {
      final sample = sampleMap();
      final ghost = sample.graph.topLevel.firstWhere(
        (n) => n.kind == CodeNodeKind.ghostParent,
      );
      final samplePositions = worldPositions(sample);

      final container = findContainer(
        samplePositions[ghost.id]!,
        sample,
        samplePositions,
      );

      expect([
        ghost.id,
        ...sample.graph.childrenOf(ghost.id).map((n) => n.id),
      ], contains(container));
    });
  });
}
