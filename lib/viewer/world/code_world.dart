import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/theme/code_world_colors.dart';
import 'package:dart_code_3d/viewer/navigation/collisions.dart';
import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:dart_code_3d/viewer/world/inverted_mesh.dart';
import 'package:dart_code_3d/viewer/world/picking.dart';
import 'package:dart_code_3d/viewer/world/scene_content.dart';
import 'package:dart_code_3d/viewer/world/sphere_detail.dart';
import 'package:dart_code_3d/viewer/world/sphere_instance.dart';
import 'package:dart_code_3d/viewer/world/view_camera.dart';
import 'package:dart_code_3d/viewer/world/visibility.dart';
import 'package:dart_code_3d/viewer/world/world_transforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// The 3D world of a code map: owns the flutter_scene [Scene] (imperative
/// style) and everything derived from the map that the renderer needs.
///
/// [show] tells it what is visible (which sphere the camera is in, the view
/// mode, the link kinds); the scene is rebuilt from that. Everything but the
/// scene itself is plain Dart, so it is unit-tested; spheres are drawn with
/// one [InstancedMesh] per material and links with one
/// [LineSegmentsGeometry] per kind, width and dimness.
class CodeWorld {
  /// Derives the world of [map], colored with [colors]. It starts showing
  /// the top level with every link kind.
  factory(CodeMap map, CodeWorldColors colors) {
    final positions = cachedWorldPositions(map);
    final index = VisibilityIndex.of(map);
    return CodeWorld._(
      map: map,
      colors: colors,
      index: index,
      positions: positions,
      radius: worldRadius(map),
      startPose: computeStartPose(map, positions),
      obstacles: [
        for (final node in map.graph.topLevel)
          if (node.kind == CodeNodeKind.externalPackage)
            (
              center: positions[node.id]!,
              radius: map.placements[node.id]!.radius,
            ),
      ],
    );
  }

  new _({
    required this.map,
    required this.colors,
    required this.index,
    required this.positions,
    required this.radius,
    required this.startPose,
    required this.obstacles,
  }) : _visible = resolveVisibility(
         index: index,
         containerId: null,
         mode: ViewMode.interior,
         linkKinds: const {...LinkKind.values},
       ) {
    content = _contentFor(_visible, ViewMode.interior);
  }

  /// The code map shown.
  final CodeMap map;

  /// The theme colors used.
  final CodeWorldColors colors;

  /// The precomputed ancestor chains of [map].
  final VisibilityIndex index;

  /// World-space center of every node.
  final Map<String, Vector3> positions;

  /// Radius of the sphere around the origin that holds the top level.
  final double radius;

  /// Where the camera starts: in front of the entry node.
  final CameraPose startPose;

  /// The solid spheres (external packages) the camera cannot enter.
  final List<Obstacle> obstacles;

  VisibleWorld _visible;
  ViewMode _mode = ViewMode.interior;
  String? _selectedId;

  /// What is drawn now.
  late SceneContent content;

  /// The number of spheres drawn (the top level until [show] says more).
  int get instanceCount => content.sphereCount;

  /// The number of link segments drawn.
  int get linkCount => content.linkCount;

  /// The sphere the camera is in (the world when null), as last shown.
  String? get containerId => _visible.openContainers.lastOrNull;

  /// The spheres a click can hit: everything drawn closed.
  Iterable<Pickable> get pickables => [
    for (final sphere in [
      ...content.solid,
      ...content.ghosts,
      ...content.packages,
    ])
      (id: sphere.nodeId, center: sphere.center, radius: sphere.radius),
  ];

  /// The selected node (null for none), even when it is hidden inside a
  /// closed sphere.
  String? get selectedId => _selectedId;

  /// The sphere that shows the selection: the selected node itself when it
  /// is drawn, otherwise its nearest drawn ancestor (the sphere it is inside
  /// of), or null when nothing selected is drawn.
  SphereInstance? get highlighted {
    final selected = _selectedId;
    if (selected == null) return null;
    final drawn = _visible.visibleSpheres.toSet();
    for (final id in index.chainOf(selected)) {
      if (!drawn.contains(id)) continue;
      return [
        ...content.solid,
        ...content.ghosts,
        ...content.packages,
      ].firstWhere((sphere) => sphere.nodeId == id);
    }
    return null;
  }

  /// Selects node [id] (nothing when null): [highlighted] shows it.
  void select(String? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    _syncHighlight();
  }

  /// Shows [visible] (with the shells drawn for [mode]): rebuilds the
  /// content, and the scene when it exists.
  void show(VisibleWorld visible, ViewMode mode) {
    if (identical(visible, _visible) && mode == _mode) return;
    if (visible == _visible && mode == _mode) return;
    final previousShells = content.shells;
    _visible = visible;
    _mode = mode;
    content = _contentFor(visible, mode);
    if (!listEquals(previousShells, content.shells)) _shellAge = 0;
    final scene = _scene;
    // The scene needs a GPU, so it never exists in unit tests.
    if (scene != null) _populate(scene); // coverage:ignore-line
  }

  SceneContent _contentFor(VisibleWorld visible, ViewMode mode) {
    final container = visible.openContainers.lastOrNull;
    return buildSceneContent(
      map: map,
      positions: positions,
      colors: colors,
      visible: visible,
      mode: mode,
      scale: container == null ? radius : map.placements[container]!.radius,
    );
  }

  /// A camera at [pose] (the [startPose] by default) for a view of [size],
  /// with a field of view adapted to its aspect ratio and clip planes that
  /// hold the whole world.
  PerspectiveCamera camera(Size size, {CameraPose? pose}) {
    final at = pose ?? startPose;
    final far = (at.position.length + radius) * 2;
    return PerspectiveCamera(
      position: at.position,
      target: at.target,
      fovRadiansY: fovYFor(size),
      fovNear: nearDepthFor(_scale),
      fovFar: far,
    );
  }

  /// The radius of the sphere the camera is in (the world's at the top level).
  double get _scale =>
      containerId == null ? radius : map.placements[containerId]!.radius;

  /// The vertical field of view for a view of [size] (wider on portrait
  /// screens), shared by the renderer's camera and the [ViewCamera] that
  /// labels and picking use.
  double fovYFor(Size size) =>
      fovYForAspect(size.height == 0 ? 1 : size.width / size.height);

  // coverage:ignore-start
  // Needs a GPU context, which `flutter test` does not have; covered by the
  // 3D visual tests (integration_test/visual).

  Scene? _scene;
  double _shellAge = 0;
  bool _animate = true;
  late Vector3 _cameraPosition = startPose.position;
  final _linkGeometries = <LinkBatch, LineSegmentsGeometry>{};
  final _shellMaterials = <UnlitMaterial>[];
  final _groups = <_SphereGroup>[];
  double _detailAge = 0;
  // Lazy: a geometry is uploaded to the GPU when it is created.
  late final _geometries = <SphereDetail, Geometry>{
    for (final detail in SphereDetail.values)
      detail: SphereGeometry(
        radius: 1,
        segments: detail.segments,
        rings: detail.rings,
      ),
  };
  Node? _highlightNode;
  Matrix4 _highlightBase = Matrix4.identity();
  double _time = 0;

  /// The scene, built on first use: read it only after
  /// `Scene.initializeStaticResources()` completed.
  Scene get scene {
    final existing = _scene;
    if (existing != null) return existing;
    final created = Scene();
    created.highlightStyle.thickness = 4;
    _populate(created);
    return _scene = created;
  }

  /// Advances the shells' fade-in by [deltaSeconds] (without [animate] they
  /// show at their final opacity at once), and sizes the links for a camera
  /// at [cameraPosition].
  void tick(
    double deltaSeconds, {
    required bool animate,
    required Vector3 cameraPosition,
  }) {
    _animate = animate;
    _cameraPosition = cameraPosition.clone();
    // The spheres' detail follows the camera, ten times a second at most.
    _detailAge += deltaSeconds;
    if (deltaSeconds == 0 || _detailAge >= 0.1) {
      _detailAge = 0;
      for (final group in _groups) {
        group.deal(SphereDetail.allOf(group.spheres, _cameraPosition));
      }
    }
    _shellAge += deltaSeconds;
    _time += deltaSeconds;
    // The selection breathes a little (not when animations are disabled).
    final highlight = _highlightNode;
    if (highlight != null) {
      final pulse = animate ? 1 + 0.04 * math.sin(_time * 4) : 1.0;
      highlight.localTransform = _highlightBase.clone()
        ..scaleByDouble(pulse, pulse, pulse, 1);
    }
    for (final (i, material) in _shellMaterials.indexed) {
      final shell = content.shells[i];
      final alpha = shellOpacity(_shellAge, shell.opacity, animate: animate);
      // Assign through the setter: it tells the renderer the material changed.
      if (material.baseColorFactor.a != alpha) {
        final c = shell.sphere.color;
        material.baseColorFactor = Vector4(c.r, c.g, c.b, alpha);
      }
    }
    // Links keep a steady look from any distance. Changing the width costs
    // a pass over the segments, so only do it when it is visibly different.
    final distance = _cameraPosition.distanceTo(content.center);
    for (final MapEntry(key: batch, value: geometry)
        in _linkGeometries.entries) {
      final target = content.widthOf(batch.widthBucket, distance);
      if ((geometry.width - target).abs() > 0.1 * target) {
        geometry.width = target;
      }
    }
  }

  /// A unit sphere seen from the inside: its inner faces are the front ones.
  late final Geometry _dome = MeshGeometry.fromMeshData(
    invertedFaces(SphereGeometry(radius: 1).extractMeshData()),
  );

  static PhysicallyBasedMaterial _material({
    double roughness = 0.45,
    double metallic = 0,
    double alpha = 1,
  }) => PhysicallyBasedMaterial()
    ..roughnessFactor = roughness
    ..metallicFactor = metallic
    ..baseColorFactor = Vector4(1, 1, 1, alpha)
    ..alphaMode = alpha < 1 ? AlphaMode.blend : AlphaMode.opaque;

  /// A sphere for the highlight: looks like the instance it covers.
  late final Geometry _unitSphere = _geometries[SphereDetail.high]!;

  /// Puts the outlined copy of the highlighted sphere in the scene (and takes
  /// the previous one out).
  void _syncHighlight() {
    final scene = _scene;
    if (scene != null) _updateHighlight(scene);
  }

  void _updateHighlight(Scene scene) {
    final previous = _highlightNode;
    if (previous != null) scene.remove(previous);
    _highlightNode = null;
    final target = highlighted;
    if (target == null) return;
    // The same material as the instance, so the copy is not seen: only the
    // outline Node.highlightColor draws around it is.
    final material =
        (content.ghosts.contains(target)
              ? _material(roughness: 0.6, alpha: 0.35)
              : content.packages.contains(target)
              ? _material(roughness: 0.3, metallic: 0.9)
              : _material())
          ..baseColorFactor = target.color;
    _highlightBase = target.transform;
    _highlightNode =
        Node(
            name: 'selection',
            localTransform: _highlightBase,
            mesh: Mesh(_unitSphere, material),
            // The outline pass takes the color as it appears on screen (sRGB),
            // whatever the docs of Node.highlightColor say.
          )
          ..highlightColor = Vector4(
            colors.selection.r,
            colors.selection.g,
            colors.selection.b,
            colors.selection.a,
          );
    scene.add(_highlightNode!);
  }

  void _populate(Scene scene) {
    scene.removeAll();
    _shellMaterials.clear();
    _linkGeometries.clear();
    _highlightNode = null;
    PhysicallyBasedMaterial material({
      double roughness = 0.45,
      double metallic = 0,
      double alpha = 1,
    }) => _material(roughness: roughness, metallic: metallic, alpha: alpha);

    _groups.clear();
    void spheres(String name, List<SphereInstance> list, Material material) {
      if (list.isEmpty) return;
      // One mesh per level of detail, all sharing the material: tick() deals
      // the spheres out between them by how large each looks.
      final group = _SphereGroup(list, {
        for (final detail in SphereDetail.values)
          detail: InstancedMesh(
            geometry: _geometries[detail]!,
            material: material,
          ),
      });
      _groups.add(group);
      for (final MapEntry(key: detail, value: mesh) in group.meshes.entries) {
        scene.add(
          Node(name: '$name ${detail.name}')
            ..addComponent(InstancedMeshComponent(mesh)),
        );
      }
    }

    spheres('solid', content.solid, material());
    spheres(
      'packages',
      content.packages,
      material(roughness: 0.3, metallic: 0.9),
    );
    spheres('ghosts', content.ghosts, material(roughness: 0.6, alpha: 0.35));

    for (final shell in content.shells) {
      // Blended and unlit, a flat tint: the dome covers the whole screen, and
      // shading every pixel of it was the biggest cost of being inside a
      // sphere. tick() sets its color and opacity. (A blended material is
      // always back-face culled, so the dome's geometry is inverted instead.)
      final tint = shell.sphere.color;
      final shellMaterial = UnlitMaterial()
        ..baseColorFactor = Vector4(tint.r, tint.g, tint.b, 0.5)
        ..alphaMode = AlphaMode.blend;
      _shellMaterials.add(shellMaterial);
      scene.add(
        Node(
          name: 'shell ${shell.sphere.nodeId}',
          localTransform: shell.sphere.transform,
          mesh: Mesh(_dome, shellMaterial),
        ),
      );
    }

    for (final MapEntry(key: batch, value: segments) in content.links.entries) {
      final points = Float32List(segments.length * 6);
      for (final (i, (from, to)) in segments.indexed) {
        points
          ..[i * 6] = from.x
          ..[i * 6 + 1] = from.y
          ..[i * 6 + 2] = from.z
          ..[i * 6 + 3] = to.x
          ..[i * 6 + 4] = to.y
          ..[i * 6 + 5] = to.z;
      }
      final color = linearColor(colors.links[batch.kind]!);
      final linkMaterial = UnlitMaterial()
        ..baseColorFactor = Vector4(
          color.r,
          color.g,
          color.b,
          batch.dim ? 0.35 : 0.9,
        )
        ..alphaMode = AlphaMode.blend
        ..doubleSided = true;
      final geometry = LineSegmentsGeometry(
        LineSegmentData(positions: points),
        width: content.widthOf(
          batch.widthBucket,
          _cameraPosition.distanceTo(content.center),
        ),
      );
      _linkGeometries[batch] = geometry;
      scene.add(
        Node(
          name: 'links ${batch.kind.name} ${batch.widthBucket}',
          mesh: Mesh(geometry, linkMaterial),
        ),
      );
    }
    _updateHighlight(scene);
    // New shells start from the current animation state (invisible, then
    // fading in), not at full opacity.
    tick(0, animate: _animate, cameraPosition: _cameraPosition);
  }

  // coverage:ignore-end
}

// coverage:ignore-start
// Holds GPU meshes, like the scene above: covered by the 3D visual tests.

/// A set of spheres drawn with one mesh per [SphereDetail].
class _SphereGroup {
  new(this.spheres, this.meshes);

  final List<SphereInstance> spheres;
  final Map<SphereDetail, InstancedMesh> meshes;
  List<SphereDetail>? _dealt;

  /// Puts each sphere in the mesh of its [details], when they changed.
  void deal(List<SphereDetail> details) {
    if (listEquals(details, _dealt)) return;
    _dealt = details;
    for (final mesh in meshes.values) {
      mesh.clearInstances();
    }
    for (final (i, sphere) in spheres.indexed) {
      meshes[details[i]]!.addInstance(sphere.transform, color: sphere.color);
    }
  }
}

// coverage:ignore-end
