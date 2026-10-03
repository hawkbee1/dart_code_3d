import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group('worldPositions', () {
    test('adds the placements along the ancestor chain', () {
      final positions = worldPositions(worldMap());

      expect(positions['main'], Vector3(0, 0, 10));
      expect(positions['A'], Vector3(4, 0, 0));
      expect(positions['A.m'], Vector3(5, 0, 0));
      expect(positions, hasLength(4));
    });
  });

  group('worldRadius', () {
    test('holds every top-level sphere', () {
      expect(worldRadius(worldMap()), closeTo(21.6, 1e-9));
    });

    test('is at least 1', () {
      final empty = CodeMap(
        graph: CodeGraph(
          project: worldMap(entryNodeId: null).graph.project,
          nodes: const {},
        ),
        placements: const {},
      );

      expect(worldRadius(empty), 1);
    });
  });
}
