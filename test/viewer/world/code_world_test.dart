import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(CodeWorld, () {
    test('draws one instance per top-level node', () {
      final world = CodeWorld(worldMap(), CodeWorldColors.light);

      expect(world.instanceCount, 3);
      expect(world.positions['A.m'], Vector3(5, 0, 0));
      expect(world.radius, closeTo(21.6, 1e-9));
      expect(world.colors, CodeWorldColors.light);
    });

    test('draws the top level of the sample, the entry node in front', () {
      final map = sampleMap();

      final world = CodeWorld(map, CodeWorldColors.dark);

      expect(world.instanceCount, map.graph.topLevel.length);
      expect(world.instanceCount, greaterThan(20));
      expect(
        world.startPose.target,
        world.positions[map.graph.project.entryNodeId],
      );
    });

    group('camera', () {
      test('starts at the start pose, holding the whole world', () {
        final world = CodeWorld(worldMap(), CodeWorldColors.light);

        final camera = world.camera(const Size(1600, 900));

        expect(camera.position, world.startPose.position);
        expect(camera.target, world.startPose.target);
        expect(camera.fovRadiansY, defaultFovY);
        expect(camera.fovNear, 0.05);
        expect(
          camera.fovFar,
          greaterThan(world.startPose.position.length + world.radius),
        );
      });

      test('widens the field of view on portrait screens', () {
        final world = CodeWorld(worldMap(), CodeWorldColors.light);

        expect(
          world.camera(const Size(390, 844)).fovRadiansY,
          fovYForAspect(390 / 844),
        );
        expect(world.camera(const Size(100, 0)).fovRadiansY, fovYForAspect(1));
      });

      test('can use another pose', () {
        final world = CodeWorld(worldMap(), CodeWorldColors.light);
        final pose = CameraPose(
          position: Vector3(1, 2, 3),
          target: Vector3.zero(),
        );

        expect(
          world.camera(const Size(1, 1), pose: pose).position,
          pose.position,
        );
      });
    });
  });
}
