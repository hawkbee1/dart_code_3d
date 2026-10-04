import 'package:code_graph/code_graph.dart';
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

    group('show', () {
      late CodeWorld world;
      late VisibilityIndex index;

      setUp(() {
        world = CodeWorld(nestedMap(), CodeWorldColors.light);
        index = VisibilityIndex.of(world.map);
      });

      VisibleWorld resolve(String? container, [ViewMode? mode]) =>
          resolveVisibility(
            index: index,
            containerId: container,
            mode: mode ?? ViewMode.interior,
            linkKinds: {...LinkKind.values},
          );

      test('starts on the top level with every link kind', () {
        expect(world.instanceCount, 5);
        expect(world.linkCount, 6);
        expect(world.containerId, isNull);
        expect(world.content.shells, isEmpty);
      });

      test('draws what is inside the container the camera is in', () {
        world.show(resolve('A'), ViewMode.interior);

        expect(world.containerId, 'A');
        expect(world.instanceCount, 2);
        expect(world.linkCount, 1);
        expect(world.content.shells.single.sphere.nodeId, 'A');
      });

      test('draws the rest of the world too in window view', () {
        world.show(resolve('A', ViewMode.window), ViewMode.window);

        expect(world.instanceCount, 6);
        expect(world.content.shells.single.opacity, windowShellOpacity);
      });

      test('bounds link widths by the level it shows', () {
        expect(world.content.linkScale, world.radius);

        world.show(resolve('A'), ViewMode.interior);

        // Class A is 3 across: much smaller than the world.
        expect(world.content.linkScale, 3);
        expect(world.radius, greaterThan(20));
      });

      test('keeps its content when shown the same thing again', () {
        world.show(resolve('A'), ViewMode.interior);
        final content = world.content;

        world.show(resolve('A'), ViewMode.interior);
        expect(world.content, same(content));

        // The same visible world and mode, built again: no rebuild either.
        final again = resolve('A');
        world.show(again, ViewMode.interior);
        expect(world.content, same(content));
      });

      test('rebuilds when only the mode changes', () {
        final visible = resolve('A');
        world.show(visible, ViewMode.interior);
        final content = world.content;

        world.show(visible, ViewMode.window);

        expect(world.content, isNot(same(content)));
        expect(world.content.shells.single.opacity, windowShellOpacity);
      });
    });

    group('selection', () {
      late CodeWorld world;
      late VisibilityIndex index;

      setUp(() {
        world = CodeWorld(nestedMap(), CodeWorldColors.light);
        index = VisibilityIndex.of(world.map);
      });

      void showContainer(String? container) => world.show(
        resolveVisibility(
          index: index,
          containerId: container,
          mode: ViewMode.interior,
          linkKinds: {...LinkKind.values},
        ),
        ViewMode.interior,
      );

      test('lists the spheres a click can hit', () {
        final pickables = world.pickables.toList();

        expect(pickables.map((p) => p.id), ['main', 'A', 'C', 'G', 'pkg']);
        final a = pickables.singleWhere((p) => p.id == 'A');
        expect(a.center, Vector3.zero());
        expect(a.radius, 3);
      });

      test('lists what is inside the container the camera is in', () {
        showContainer('A');

        expect(world.pickables.map((p) => p.id), ['A.m', 'A.B']);
      });

      test('highlights the selected sphere', () {
        world.select('A');

        expect(world.selectedId, 'A');
        expect(world.highlighted!.nodeId, 'A');
        expect(world.highlighted!.radius, 3);
      });

      test('highlights nothing without a selection', () {
        expect(world.selectedId, isNull);
        expect(world.highlighted, isNull);

        world
          ..select('A')
          ..select(null);

        expect(world.highlighted, isNull);
      });

      test('highlights the sphere that holds a hidden selection', () {
        world.select('A.B.n');

        expect(world.selectedId, 'A.B.n');
        expect(world.highlighted!.nodeId, 'A');
      });

      test('follows the selection down as spheres are entered', () {
        world.select('A.B.n');

        showContainer('A');
        expect(world.highlighted!.nodeId, 'A.B');

        showContainer('A.B');
        expect(world.highlighted!.nodeId, 'A.B.n');
      });

      test('highlights nothing that is not drawn', () {
        showContainer('A');

        world.select('C.k');

        expect(world.highlighted, isNull);
        expect(world.selectedId, 'C.k');
      });

      test('selecting the same node again changes nothing', () {
        world.select('C');
        final highlighted = world.highlighted;

        world.select('C');

        expect(world.highlighted, same(highlighted));
      });
    });

    test('has the field of view of a view of a given size', () {
      final world = CodeWorld(worldMap(), CodeWorldColors.light);

      expect(world.fovYFor(const Size(1600, 900)), defaultFovY);
      expect(world.fovYFor(const Size(390, 844)), fovYForAspect(390 / 844));
      expect(world.fovYFor(const Size(100, 0)), fovYForAspect(1));
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
