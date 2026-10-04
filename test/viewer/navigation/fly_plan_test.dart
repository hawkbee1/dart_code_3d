import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

CodeWorld _worldWith(Map<String, (double, double)> radiusAndOffset) {
  // A container `X` (radius first) holding one child `X.c` (radius, x).
  final (xRadius, _) = radiusAndOffset['X']!;
  final (childRadius, childX) = radiusAndOffset['X.c']!;
  return CodeWorld(
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
      placements: {
        'X': Placement(x: 0, y: 0, z: 0, radius: xRadius),
        'X.c': Placement(x: childX, y: 0, z: 0, radius: childRadius),
      },
    ),
    CodeWorldColors.light,
  );
}

void main() {
  group(flyToNodePlan, () {
    late CodeWorld world;

    setUp(() => world = CodeWorld(nestedMap(), CodeWorldColors.light));

    String? containerAt(CameraPose pose) =>
        findContainer(pose.position, world.map, world.positions);

    List<CameraPose> plan(String? current, String target) => flyToNodePlan(
      world: world,
      from: Vector3(0, 0, 40),
      current: current,
      target: target,
    );

    test('goes straight to a top-level node from the world', () {
      final poses = plan(null, 'C');

      expect(poses, hasLength(1));
      expect(poses.single.target, world.positions['C']);
      expect(containerAt(poses.single), isNull);
      // About four radii away.
      expect(
        poses.single.position.distanceTo(world.positions['C']!),
        closeTo(3 * 4, 1e-3),
      );
    });

    test('enters the containers that hold a deep node, one by one', () {
      final poses = plan(null, 'A.B.n');

      expect(poses, hasLength(3));
      expect(poses.map(containerAt), ['A', 'A.B', 'A.B']);
      expect(poses.last.target, world.positions['A.B.n']);
    });

    test('leaves the containers that do not hold the target first', () {
      final poses = plan('A.B', 'C.k');

      expect(poses, hasLength(3));
      // Out of A, into C, then facing the method.
      expect(poses.map(containerAt), [null, 'C', 'C']);
      expect(poses.last.target, world.positions['C.k']);
    });

    test('goes straight to a sibling when already in its container', () {
      final poses = plan('A', 'A.m');

      expect(poses, hasLength(1));
      expect(containerAt(poses.single), 'A');
    });

    test('leaves only as far as the container both share', () {
      final poses = plan('A.B', 'A.m');

      // Out of A.B (landing inside A), then facing the method.
      expect(poses, hasLength(2));
      expect(poses.map(containerAt), ['A', 'A']);
    });

    test('leaves a container to reach a top-level node', () {
      final poses = plan('A', 'pkg');

      expect(poses.map(containerAt), [null, null]);
      expect(poses.last.target, world.positions['pkg']);
    });

    test('keeps clear of the solid package spheres', () {
      final poses = plan(null, 'pkg');
      final package = world.obstacles.single;

      expect(
        poses.last.position.distanceTo(package.center),
        greaterThanOrEqualTo(package.radius + collisionMargin),
      );
    });

    test('lands on the side of the camera when it can', () {
      final poses = flyToNodePlan(
        world: world,
        from: Vector3(60, 0, 0),
        current: null,
        target: 'C',
      );

      // C is at (20, 0, 0): the camera comes from +X, so it lands on +X.
      expect(poses.single.position.x, greaterThan(world.positions['C']!.x));
      expect(poses.single.position.y, closeTo(0, 1e-3));
    });
  });

  group(facingPose, () {
    test('comes closer when the container is cramped', () {
      // X has radius 2.5 and its child radius 1 at the center: four and
      // three radii from the child are outside X, two is inside.
      final world = _worldWith({'X': (2.5, 0), 'X.c': (1, 0)});

      final pose = facingPose(
        world: world,
        target: 'X.c',
        from: Vector3(10, 0, 0),
      );

      expect(pose.position.length, closeTo(2, 1e-3));
      expect(findContainer(pose.position, world.map, world.positions), 'X');
    });

    test('keeps its distance from a target that fills its container', () {
      // Nothing fits at any distance: face from the preferred distance on
      // the side of the camera anyway.
      final world = _worldWith({'X': (1, 0), 'X.c': (0.9, 0)});

      final pose = facingPose(
        world: world,
        target: 'X.c',
        from: Vector3(10, 0, 0),
      );

      expect(pose.position.distanceTo(Vector3(3.6, 0, 0)), lessThan(1e-3));
      expect(pose.target, Vector3.zero());
    });
  });

  group(flightDuration, () {
    test('is at least 0.6 s for a short hop', () {
      expect(flightDuration(0, 100), 0.6);
      expect(flightDuration(1, 100), closeTo(0.6045, 1e-9));
    });

    test('grows with the distance, to 1.5 s across the world', () {
      expect(flightDuration(100, 100), closeTo(1.05, 1e-9));
      expect(flightDuration(200, 100), 1.5);
      expect(flightDuration(5000, 100), 1.5);
    });

    test('is the longest in a world without size', () {
      expect(flightDuration(10, 0), 1.5);
    });
  });
}
