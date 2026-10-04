import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group(ViewCamera, () {
    // A 90° vertical field of view: tan(45°) = 1, so the view's edges are at
    // |x| = depth (times the aspect) and |y| = depth.
    const quarterTurn = math.pi / 2;

    ViewCamera lookingNorth({Size size = const Size(100, 100)}) => ViewCamera(
      position: Vector3.zero(),
      forward: Vector3(0, 0, -1),
      fovY: quarterTurn,
      size: size,
    );

    group('project', () {
      test('puts what is straight ahead in the middle', () {
        final at = lookingNorth().project(Vector3(0, 0, -10))!;

        expect(at.dx, closeTo(50, 1e-9));
        expect(at.dy, closeTo(50, 1e-9));
      });

      test('puts the right and the top at the edges', () {
        final camera = lookingNorth();

        expect(camera.project(Vector3(1, 0, -1))!.dx, closeTo(100, 1e-9));
        expect(camera.project(Vector3(-1, 0, -1))!.dx, closeTo(0, 1e-9));
        expect(camera.project(Vector3(0, 1, -1))!.dy, closeTo(0, 1e-9));
        expect(camera.project(Vector3(0, -1, -1))!.dy, closeTo(100, 1e-9));
      });

      test('widens the horizontal field with the aspect ratio', () {
        final wide = lookingNorth(size: const Size(200, 100));

        expect(wide.project(Vector3(2, 0, -1))!.dx, closeTo(200, 1e-9));
        expect(wide.project(Vector3(1, 0, -1))!.dx, closeTo(150, 1e-9));
      });

      test('has nothing behind the camera or in front of its near plane', () {
        final camera = lookingNorth();

        expect(camera.project(Vector3(0, 0, 5)), isNull);
        expect(camera.project(Vector3(0, 0, -nearDepth / 2)), isNull);
        expect(camera.project(Vector3(0, 0, -nearDepth * 2)), isNotNull);
      });

      test('turns with the camera', () {
        // Looking east (+X): the world's north (-Z) is on the left.
        final camera = ViewCamera(
          position: Vector3.zero(),
          forward: Vector3(1, 0, 0),
          fovY: quarterTurn,
          size: const Size(100, 100),
        );

        expect(camera.project(Vector3(1, 0, -1))!.dx, closeTo(0, 1e-9));
        expect(camera.project(Vector3(1, 0, 1))!.dx, closeTo(100, 1e-9));
      });

      test('keeps a horizontal right when looking up or down', () {
        final up = ViewCamera(
          position: Vector3.zero(),
          forward: Vector3(0, 1, 0),
          fovY: quarterTurn,
          size: const Size(100, 100),
        );

        expect(up.right, Vector3(1, 0, 0));
        expect(up.project(Vector3(0, 1, 0))!.dx, closeTo(50, 1e-9));
      });
    });

    group('rayAt', () {
      test('goes straight ahead through the middle', () {
        final ray = lookingNorth().rayAt(const Offset(50, 50));

        expect(ray.origin, Vector3.zero());
        expect(ray.direction.distanceTo(Vector3(0, 0, -1)), lessThan(1e-9));
      });

      test('undoes project', () {
        final camera = ViewCamera(
          position: Vector3(3, 2, 8),
          forward: Vector3(-1, -0.3, -2),
          fovY: 0.9,
          size: const Size(390, 844),
        );
        for (final point in [
          Vector3(2, 1, 0),
          Vector3(-5, 4, -30),
          Vector3(8, -2, -12),
        ]) {
          final at = camera.project(point)!;

          final ray = camera.rayAt(at);

          final expected = (point - camera.position).normalized();
          expect(ray.direction.distanceTo(expected), lessThan(1e-6));
        }
      });
    });

    test('knows the depth of a point', () {
      final camera = lookingNorth();

      expect(camera.depthOf(Vector3(5, 5, -7)), closeTo(7, 1e-9));
      expect(camera.depthOf(Vector3(0, 0, 3)), closeTo(-3, 1e-9));
    });

    group('screenRadius', () {
      test('shrinks with the distance', () {
        final camera = lookingNorth();

        expect(camera.screenRadius(Vector3(0, 0, -10), 1), closeTo(5, 1e-9));
        expect(camera.screenRadius(Vector3(0, 0, -20), 1), closeTo(2.5, 1e-9));
      });

      test('is unbounded for what is behind or at the camera', () {
        final camera = lookingNorth();

        expect(camera.screenRadius(Vector3(0, 0, 10), 1), double.infinity);
        expect(camera.screenRadius(Vector3.zero(), 1), double.infinity);
      });
    });

    test('has no usable aspect for an empty view, but does not crash', () {
      final empty = lookingNorth(size: Size.zero);

      expect(
        empty.rayAt(Offset.zero).direction.distanceTo(Vector3(0, 0, -1)),
        lessThan(1e-9),
      );
    });

    test('is built from a pose', () {
      final camera = ViewCamera.fromPose(
        CameraPose(position: Vector3(0, 0, 5), target: Vector3.zero()),
        const Size(100, 100),
        fovY: quarterTurn,
      );

      expect(camera.position, Vector3(0, 0, 5));
      expect(camera.forward.distanceTo(Vector3(0, 0, -1)), lessThan(1e-9));
    });
  });
}
