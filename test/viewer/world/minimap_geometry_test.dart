import 'dart:ui' show Offset, Size;

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

MinimapSphere _sphere(String id, double x, double z, double radius) =>
    (id: id, center: Vector3(x, 0, z), radius: radius);

void main() {
  group(MinimapProjection, () {
    test('fits the spheres into the square', () {
      // Spheres from -1 to 11 on both axes: 12 world units across.
      final projection = MinimapProjection.fit(
        [_sphere('a', 0, 0, 1), _sphere('b', 10, 10, 1)],
        const Size(120, 120),
        padding: 0,
      );

      expect(projection.scale, closeTo(10, 1e-9));
      expect(projection.toMap(Vector3(5, 0, 5)), const Offset(60, 60));
      expect(projection.toMap(Vector3(-1, 0, -1)), Offset.zero);
      expect(projection.toMap(Vector3(11, 0, 11)), const Offset(120, 120));
    });

    test('puts north (-Z) at the top and east (+X) on the right', () {
      final projection = MinimapProjection.fit(
        [_sphere('a', -5, -5, 0), _sphere('b', 5, 5, 0)],
        const Size(100, 100),
        padding: 0,
      );

      final northWest = projection.toMap(Vector3(-5, 0, -5));
      final southEast = projection.toMap(Vector3(5, 0, 5));
      expect(southEast.dx, greaterThan(northWest.dx));
      expect(southEast.dy, greaterThan(northWest.dy));
    });

    test('keeps the aspect ratio, fitting the longer side', () {
      final projection = MinimapProjection.fit(
        [_sphere('a', 0, 0, 0), _sphere('b', 100, 10, 0)],
        const Size(200, 100),
        padding: 0,
      );

      // 100 units across 200 px: 2 px per unit; the 10 units of depth only
      // use 20 px of the 100.
      expect(projection.scale, closeTo(2, 1e-9));
      expect(projection.toMap(Vector3(50, 0, 5)), const Offset(100, 50));
    });

    test('leaves room for the padding', () {
      final projection = MinimapProjection.fit([
        _sphere('a', 0, 0, 5),
      ], const Size(100, 100));

      // 10 units into 100 - 2 * 8 px.
      expect(projection.scale, closeTo(8.4, 1e-9));
    });

    test('shows a unit world when there is nothing', () {
      final projection = MinimapProjection.fit(const [], const Size(100, 100));

      expect(projection.toMap(Vector3.zero()), const Offset(50, 50));
      expect(projection.scale, greaterThan(0));
    });

    test('copes with spheres that have no extent', () {
      final projection = MinimapProjection.fit([
        _sphere('a', 3, 3, 0),
      ], const Size(100, 100));

      expect(projection.toMap(Vector3(3, 0, 3)), const Offset(50, 50));
      expect(projection.scale.isFinite, isTrue);
    });

    test('falls back to one pixel per unit in a tiny square', () {
      final projection = MinimapProjection.fit([
        _sphere('a', 0, 0, 5),
      ], const Size(10, 10));

      expect(projection.scale, 1);
    });

    test('keeps a point inside the map when asked', () {
      final projection = MinimapProjection.fit(
        [_sphere('a', 0, 0, 1)],
        const Size(100, 100),
        padding: 0,
      );

      expect(
        projection.toMapClamped(Vector3(500, 0, -500)),
        const Offset(96, 4),
      );
      expect(
        projection.toMapClamped(Vector3(-500, 0, 500)),
        const Offset(4, 96),
      );
      expect(projection.toMapClamped(Vector3.zero()), const Offset(50, 50));
    });

    group('place', () {
      late MinimapProjection projection;

      setUp(() {
        // 20 world units over 100 px: 5 px per unit, centered on the origin.
        projection = MinimapProjection.fit(
          [_sphere('a', 0, 0, 10)],
          const Size(100, 100),
          padding: 0,
        );
      });

      test('draws a sphere on the map as a circle of its size', () {
        final placed = projection.place(_sphere('s', 2, -2, 3));

        expect(placed.at, const Offset(60, 40));
        expect(placed.radius, closeTo(15, 1e-9));
      });

      test('gives a tiny sphere a visible radius', () {
        final placed = projection.place(_sphere('s', 0, 0, 0.1));

        expect(placed.radius, 2);
      });

      test('pins a sphere that is off the map to the edge, as a dot', () {
        final placed = projection.place(_sphere('s', -200, 0, 30));

        expect(placed.at, const Offset(4, 50));
        expect(placed.radius, 3);
      });

      test('pins to the corner when off the map on both axes', () {
        final placed = projection.place(_sphere('s', 200, 200, 1));

        expect(placed.at, const Offset(96, 96));
      });
    });

    test('converts world lengths to pixels', () {
      final projection = MinimapProjection.fit(
        [_sphere('a', 0, 0, 5)],
        const Size(100, 100),
        padding: 0,
      );

      expect(projection.lengthToMap(2), closeTo(20, 1e-9));
    });
  });

  group(minimapHit, () {
    final spheres = [
      _sphere('big', 0, 0, 10),
      _sphere('small', 2, 2, 1),
      _sphere('far', 40, 0, 1),
    ];
    final projection = MinimapProjection.fit(
      spheres,
      const Size(200, 200),
      padding: 0,
    );

    String? hit(double x, double z, {double slop = 8}) => minimapHit(
      projection.toMap(Vector3(x, 0, z)),
      spheres,
      projection,
      slop: slop,
    );

    test('picks the sphere under the tap', () {
      expect(hit(-5, -5), 'big');
      expect(hit(40, 0), 'far');
    });

    test('prefers the smallest of the spheres that overlap', () {
      expect(hit(2, 2), 'small');
    });

    test('lets a small sphere be hit within the slop', () {
      // 1 unit is under 8 px here: a tap 1.5 units away still hits it.
      expect(hit(41.5, 0), 'far');
      expect(hit(41.5, 0, slop: 0), isNull);
    });

    test('hits nothing in empty space', () {
      expect(hit(25, 25), isNull);
    });

    test('hits a sphere off the map where it is pinned to the edge', () {
      final all = [...spheres, _sphere('away', 0, 500, 2)];
      final pinned = projection.toMapClamped(Vector3(0, 0, 500));

      expect(minimapHit(pinned, all, projection), 'away');
      // Along the same edge, away from the dot, there is nothing to tap.
      expect(minimapHit(pinned + const Offset(60, 0), all, projection), isNull);
    });
  });
}
