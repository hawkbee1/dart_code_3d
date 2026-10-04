import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group(SphereDetail, () {
    test('is full inside a sphere and when touching it', () {
      expect(SphereDetail.of(radius: 5, distance: 0), SphereDetail.high);
      expect(SphereDetail.of(radius: 5, distance: 5), SphereDetail.high);
    });

    test('goes down with the distance', () {
      expect(SphereDetail.of(radius: 1, distance: 10), SphereDetail.high);
      expect(SphereDetail.of(radius: 1, distance: 50), SphereDetail.medium);
      expect(SphereDetail.of(radius: 1, distance: 500), SphereDetail.low);
    });

    test('goes up with the radius', () {
      const distance = 100.0;

      expect(
        [
          for (final r in [0.5, 2.0, 8.0])
            SphereDetail.of(radius: r, distance: distance),
        ],
        [SphereDetail.low, SphereDetail.medium, SphereDetail.high],
      );
    });

    test('changes exactly at the shares', () {
      expect(SphereDetail.of(radius: 0.05, distance: 1), SphereDetail.high);
      expect(SphereDetail.of(radius: 0.0499, distance: 1), SphereDetail.medium);
      expect(SphereDetail.of(radius: 0.012, distance: 1), SphereDetail.medium);
      expect(SphereDetail.of(radius: 0.0119, distance: 1), SphereDetail.low);
    });

    test('can use other shares', () {
      expect(
        SphereDetail.of(
          radius: 1,
          distance: 100,
          mediumShare: 0.001,
          highShare: 0.005,
        ),
        SphereDetail.high,
      );
    });

    test('gets finer from low to high', () {
      const details = SphereDetail.values;

      expect(details.map((d) => d.segments), orderedEquals([12, 24, 48]));
      expect(details.map((d) => d.rings), orderedEquals([6, 12, 24]));
    });

    test('is worked out for every sphere from the camera', () {
      SphereInstance at(double x, double radius) => SphereInstance(
        nodeId: '$x',
        center: Vector3(x, 0, 0),
        radius: radius,
        color: Vector4.all(1),
      );

      final details = SphereDetail.allOf([
        at(10, 1),
        at(50, 1),
        at(500, 1),
      ], Vector3.zero());

      expect(details, [
        SphereDetail.high,
        SphereDetail.medium,
        SphereDetail.low,
      ]);
    });
  });
}
