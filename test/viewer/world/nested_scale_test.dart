import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(scaleNested, () {
    late CodeMap map;
    late CodeMap scaled;

    setUp(() {
      map = nestedMap();
      scaled = scaleNested(map);
    });

    double radius(String id) => scaled.placements[id]!.radius;
    double laidOut(String id) => map.placements[id]!.radius;

    test('draws spheres inside a sphere at half their size', () {
      expect(radius('A.m'), laidOut('A.m') * 0.5);
      expect(radius('A.B'), laidOut('A.B') * 0.5);
      expect(radius('C.k'), laidOut('C.k') * 0.5);
    });

    test('applies the same rule to what those spheres contain, and so on', () {
      // A.B.n is inside A.B, which is inside A: a quarter.
      expect(radius('A.B.n'), laidOut('A.B.n') * 0.25);
      // G.D.p is inside G.D, inside the ghost parent G.
      expect(radius('G.D.p'), laidOut('G.D.p') * 0.25);
    });

    test('leaves the top level as it was laid out', () {
      for (final id in ['main', 'A', 'C', 'G', 'pkg']) {
        expect(scaled.placements[id], map.placements[id]);
      }
    });

    test(
      'halves, at every level, the share of its container a sphere takes',
      () {
        for (final node in map.graph.nodes.values) {
          final parent = node.parentId;
          if (parent == null) continue;
          final before = laidOut(node.id) / laidOut(parent);
          // The container is itself drawn smaller, but so is what it holds:
          // against it, a child is half of what it was.
          final after = radius(node.id) / radius(parent);
          expect(after, closeTo(before * 0.5, 1e-9), reason: node.id);
        }
      },
    );

    test('keeps the children where they were in their container', () {
      // A.B sits 1.5 along x in A, which is at its laid-out size.
      expect(scaled.placements['A.B']!.x, 1.5);
      // A.B.n sits 0.3 up in A.B, which is drawn at half size.
      expect(scaled.placements['A.B.n']!.y, closeTo(0.15, 1e-9));
    });

    test('keeps every sphere inside the one that holds it', () {
      final positions = worldPositions(scaled);
      for (final node in scaled.graph.nodes.values) {
        final parent = node.parentId;
        if (parent == null) continue;
        final reach =
            positions[node.id]!.distanceTo(positions[parent]!) +
            radius(node.id);
        expect(
          reach,
          lessThanOrEqualTo(radius(parent) + 1e-9),
          reason: node.id,
        );
      }
    });

    test('keeps the sample map inside its spheres, as it was', () {
      final sample = sampleMap();
      final shown = scaleNested(sample);
      final before = worldPositions(sample);
      final after = worldPositions(shown);
      for (final node in sample.graph.nodes.values) {
        final parent = node.parentId;
        if (parent == null) continue;
        bool inside(Map<String, Vector3> positions, CodeMap m) =>
            positions[node.id]!.distanceTo(positions[parent]!) +
                m.placements[node.id]!.radius <=
            m.placements[parent]!.radius + 1e-6;
        if (inside(before, sample)) {
          expect(inside(after, shown), isTrue, reason: node.id);
        }
      }
    });

    test('does not touch the graph', () {
      expect(scaled.graph, same(map.graph));
    });

    test('takes another factor', () {
      final quarter = scaleNested(map, factor: 0.25);

      expect(quarter.placements['A.m']!.radius, closeTo(0.125, 1e-9));
      expect(quarter.placements['A.B.n']!.radius, closeTo(0.3 / 16, 1e-9));
    });

    test('is the map itself with a factor of one', () {
      expect(scaleNested(map, factor: 1), same(map));
    });

    test('halves by default', () {
      expect(nestedScale, 0.5);
    });
  });
}
