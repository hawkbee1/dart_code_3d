import 'package:dart_code_3d/viewer/navigation/collisions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('resolveCollisions', () {
    final obstacle = (center: Vector3(10, 0, 0), radius: 2.0);

    test('leaves a free position unchanged', () {
      expect(resolveCollisions(Vector3(0, 0, 0), [obstacle]), Vector3(0, 0, 0));
    });

    test('pushes a position inside back to the surface plus margin', () {
      final resolved = resolveCollisions(Vector3(9, 0, 0), [obstacle]);

      expect(resolved.x, closeTo(10 - 2 - collisionMargin, 1e-9));
      expect(resolved.distanceTo(obstacle.center), closeTo(2.25, 1e-9));
    });

    test('keeps a position already on the surface', () {
      final surface = Vector3(10, 0, 2 + collisionMargin);

      expect(resolveCollisions(surface, [obstacle]), surface);
    });

    test('leaves from the exact center towards +Z', () {
      expect(
        resolveCollisions(Vector3(10, 0, 0), [obstacle], margin: 0),
        Vector3(10, 0, 2),
      );
    });

    test('settles outside several touching obstacles', () {
      final obstacles = [
        (center: Vector3(-1, 0, 0), radius: 1.0),
        (center: Vector3(1, 0, 0), radius: 1.0),
      ];

      final resolved = resolveCollisions(Vector3(0, 0, 0.1), obstacles);

      // Out of both (each pass pushes out of one, then the other).
      for (final o in obstacles) {
        expect(
          resolved.distanceTo(o.center),
          greaterThanOrEqualTo(o.radius + collisionMargin - 0.01),
        );
      }
    });
  });
}
