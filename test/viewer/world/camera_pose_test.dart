import 'dart:math' as math;

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group('computeStartPose', () {
    test('looks at the entry node from the front and above', () {
      final map = worldMap();

      final pose = computeStartPose(map, worldPositions(map));

      // main has radius 0.5, framed as at least minimumFramingRadius (1.5).
      expect(pose.target, Vector3(0, 0, 10));
      expect(pose.position, Vector3(0, 1.5, 14.5));
    });

    test('uses the entry radius when it is large', () {
      final map = worldMap(entryNodeId: 'A');

      final pose = computeStartPose(map, worldPositions(map));

      expect(
        pose,
        CameraPose(position: Vector3(4, 2, 6), target: Vector3(4, 0, 0)),
      );
    });

    test('frames the origin without an entry node', () {
      final map = worldMap(entryNodeId: null);

      final pose = computeStartPose(map, worldPositions(map));

      expect(pose.target, Vector3.zero());
      expect(pose.position, Vector3(0, 1.5, 4.5));
    });
  });

  group('fovYForAspect', () {
    test('keeps the default on wide views', () {
      expect(fovYForAspect(16 / 9), defaultFovY);
      expect(fovYForAspect(2), defaultFovY);
    });

    test('widens on tall views to keep 60° horizontally', () {
      final fovY = fovYForAspect(0.5);
      final fovX = 2 * math.atan(math.tan(fovY / 2) * 0.5);

      expect(fovX, closeTo(minimumFovX, 1e-9));
      expect(fovYForAspect(1), closeTo(minimumFovX, 1e-9));
    });

    test('falls back to the default for an empty view', () {
      expect(fovYForAspect(0), defaultFovY);
    });
  });
}
