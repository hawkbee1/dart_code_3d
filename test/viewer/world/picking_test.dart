import 'dart:ui' show Offset, Size;

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

Pickable _sphere(String id, double x, double y, double z, double radius) =>
    (id: id, center: Vector3(x, y, z), radius: radius);

void main() {
  group(pickSphere, () {
    final ahead = Ray.originDirection(Vector3.zero(), Vector3(0, 0, -1));

    test('hits the nearest sphere on the ray', () {
      final spheres = [
        _sphere('far', 0, 0, -10, 1),
        _sphere('near', 0, 0, -5, 1),
      ];

      expect(pickSphere(ahead, spheres), 'near');
    });

    test('misses spheres beside the ray', () {
      expect(pickSphere(ahead, [_sphere('aside', 5, 0, -10, 1)]), isNull);
    });

    test('hits a sphere the ray only grazes', () {
      expect(pickSphere(ahead, [_sphere('edge', 1, 0, -10, 1)]), 'edge');
    });

    test('ignores spheres behind the ray', () {
      expect(pickSphere(ahead, [_sphere('behind', 0, 0, 10, 1)]), isNull);
    });

    test('ignores a sphere the ray starts inside', () {
      final spheres = [
        _sphere('around', 0, 0, 0, 5),
        _sphere('ahead', 0, 0, -10, 1),
      ];

      expect(pickSphere(ahead, spheres), 'ahead');
    });

    test('hits nothing without spheres', () {
      expect(pickSphere(ahead, const []), isNull);
    });

    test('keeps the first of two equally near spheres', () {
      final spheres = [
        _sphere('first', 0, 0, -5, 1),
        _sphere('second', 0, 0, -5, 1),
      ];

      expect(pickSphere(ahead, spheres), 'first');
    });

    test('picks what is under a screen position', () {
      final camera = ViewCamera(
        position: Vector3.zero(),
        forward: Vector3(0, 0, -1),
        fovY: 1.2,
        size: const Size(400, 800),
      );
      final spheres = [
        _sphere('middle', 0, 0, -10, 1),
        _sphere('right', 6, 0, -10, 1),
      ];

      final middle = camera.project(Vector3(0, 0, -10))!;
      final right = camera.project(Vector3(6, 0, -10))!;

      expect(pickSphere(camera.rayAt(middle), spheres), 'middle');
      expect(pickSphere(camera.rayAt(right), spheres), 'right');
      expect(pickSphere(camera.rayAt(const Offset(10, 10)), spheres), isNull);
    });
  });
}
