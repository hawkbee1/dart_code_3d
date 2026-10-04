import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(fibonacciDirections, () {
    test('gives the requested number of distinct unit vectors', () {
      final directions = fibonacciDirections(32);

      expect(directions, hasLength(32));
      for (final direction in directions) {
        expect(direction.length, closeTo(1, 1e-6));
      }
      expect({for (final d in directions) d.toString()}, hasLength(32));
    });

    test('spreads over the whole sphere', () {
      final directions = fibonacciDirections(64);

      expect(
        directions.map((d) => d.y).reduce((a, b) => a < b ? a : b),
        lessThan(-0.9),
      );
      expect(
        directions.map((d) => d.y).reduce((a, b) => a > b ? a : b),
        greaterThan(0.9),
      );
    });
  });

  group(exitPose, () {
    late CodeWorld world;

    setUp(() => world = CodeWorld(nestedMap(), CodeWorldColors.light));

    String? containerAt(Vector3 point) =>
        findContainer(point, world.map, world.positions);

    test('lands just inside a container, on the side of the camera', () {
      final pose = exitPose(
        world: world,
        target: 'A',
        from: Vector3(0, 0, 50),
        current: 'A.B',
      );

      // A is at the origin, radius 3: 94% of it, towards +Z.
      expect(
        pose.position.distanceTo(Vector3(0, 0, 3 * insideShellShare)),
        lessThan(1e-4),
      );
      expect(pose.target, Vector3.zero());
      expect(containerAt(pose.position), 'A');
    });

    test('lands outside the top-level sphere that holds the camera', () {
      final pose = exitPose(
        world: world,
        target: null,
        from: Vector3(1.5, 0, 0),
        current: 'A.B',
      );

      expect(pose.target, Vector3.zero());
      expect(pose.position.length, closeTo(3 * outsideShellShare, 1e-4));
      expect(containerAt(pose.position), isNull);
    });

    test('frames the start of the world when already there', () {
      final pose = exitPose(
        world: world,
        target: null,
        from: Vector3(0, 0, 50),
        current: null,
      );

      expect(pose, world.startPose);
    });

    test('moves round children that block the side of the camera', () {
      // Child X.c reaches past the landing point on the +X side.
      final crowded = CodeWorld(
        CodeMap(
          graph: CodeGraph(
            project: ProjectInfo(
              generator: 'test',
              source: const LocalFolderDescriptor(name: 'x'),
              createdAt: DateTime.utc(2026, 10, 4),
            ),
            nodes: const {
              'X': CodeNode(id: 'X', kind: CodeNodeKind.classDecl, name: 'X'),
              'X.c': CodeNode(
                id: 'X.c',
                kind: CodeNodeKind.method,
                name: 'c',
                parentId: 'X',
              ),
            },
          ),
          placements: const {
            'X': Placement(x: 0, y: 0, z: 0, radius: 2),
            'X.c': Placement(x: 1.5, y: 0, z: 0, radius: 0.8),
          },
        ),
        CodeWorldColors.light,
      );

      final pose = exitPose(
        world: crowded,
        target: 'X',
        from: Vector3(10, 0, 0),
        current: null,
      );

      expect(findContainer(pose.position, crowded.map, crowded.positions), 'X');
      expect(
        pose.position.distanceTo(Vector3(2 * insideShellShare, 0, 0)),
        greaterThan(0.5),
      );
      expect(pose.position.length, closeTo(2 * insideShellShare, 1e-4));
    });

    test('starts from the lattice when the camera is at the center', () {
      final pose = exitPose(
        world: world,
        target: 'A',
        from: Vector3.zero(),
        current: 'A',
      );

      expect(containerAt(pose.position), 'A');
      expect(pose.position.length, closeTo(3 * insideShellShare, 1e-4));
    });

    test('falls back to the side of the camera when nothing fits', () {
      // A package sphere is never a container, so no landing spot fits.
      final center = world.positions['pkg']!;

      final pose = exitPose(
        world: world,
        target: 'pkg',
        from: center + Vector3(0, 0, 10),
        current: null,
      );

      expect(
        pose.position.distanceTo(
          center + Vector3(0, 0, 1.6 * insideShellShare),
        ),
        lessThan(1e-4),
      );
    });
  });
}
