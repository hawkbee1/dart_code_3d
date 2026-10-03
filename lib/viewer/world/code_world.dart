import 'dart:ui' show Size;

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/theme/code_world_colors.dart';
import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:dart_code_3d/viewer/world/sphere_instance.dart';
import 'package:dart_code_3d/viewer/world/world_transforms.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// The 3D world of a code map: owns the flutter_scene [Scene] (imperative
/// style) and everything derived from the map that the renderer needs.
///
/// Everything but [scene] is plain Dart, so it is unit-tested; the
/// spheres are drawn with one [InstancedMesh] (one draw for all of them).
class CodeWorld {
  /// Derives the world of [map], colored with [colors].
  factory(CodeMap map, CodeWorldColors colors) {
    final positions = worldPositions(map);
    return CodeWorld._(
      map: map,
      colors: colors,
      positions: positions,
      instances: sphereInstances(map, positions, colors),
      radius: worldRadius(map),
      startPose: computeStartPose(map, positions),
    );
  }

  new _({
    required this.map,
    required this.colors,
    required this.positions,
    required this.instances,
    required this.radius,
    required this.startPose,
  });

  /// The code map shown.
  final CodeMap map;

  /// The theme colors used.
  final CodeWorldColors colors;

  /// World-space center of every node.
  final Map<String, Vector3> positions;

  /// The spheres drawn: the top level of the world (children appear when
  /// entering a sphere, session 13).
  final List<SphereInstance> instances;

  /// Radius of the sphere around the origin that holds the top level.
  final double radius;

  /// Where the camera starts: in front of the entry node.
  final CameraPose startPose;

  /// The number of spheres drawn.
  int get instanceCount => instances.length;

  /// A camera at [pose] (the [startPose] by default) for a view of [size],
  /// with a field of view adapted to its aspect ratio and clip planes that
  /// hold the whole world.
  PerspectiveCamera camera(Size size, {CameraPose? pose}) {
    final at = pose ?? startPose;
    final far = (at.position.length + radius) * 2;
    return PerspectiveCamera(
      position: at.position,
      target: at.target,
      fovRadiansY: fovYForAspect(
        size.height == 0 ? 1 : size.width / size.height,
      ),
      fovNear: 0.05,
      fovFar: far,
    );
  }

  // coverage:ignore-start
  // Needs a GPU context, which `flutter test` does not have; covered by the
  // 3D visual tests (integration_test/visual, scenario sample_start).

  Scene? _scene;

  /// The scene, built on first use: read it only after
  /// `Scene.initializeStaticResources()` completed.
  Scene get scene => _scene ??= _buildScene();

  Scene _buildScene() {
    final mesh = InstancedMesh(
      // 48×24 keeps silhouettes round at desktop size; LOD can come later.
      geometry: SphereGeometry(radius: 1, segments: 48, rings: 24),
      material: PhysicallyBasedMaterial()
        ..roughnessFactor = 0.45
        ..metallicFactor = 0,
    );
    for (final sphere in instances) {
      mesh.addInstance(sphere.transform, color: sphere.color);
    }
    return Scene()..add(
      Node(name: 'top level')..addComponent(InstancedMeshComponent(mesh)),
    );
  }

  // coverage:ignore-end
}
