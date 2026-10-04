import 'dart:math' as math;

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A deterministic 3D scene captured by the visual tests.
///
/// Scenarios must not depend on time: no animation, fixed camera.
class VisualScenario {
  const new({
    required this.id,
    required this.load,
    this.clearCorners = true,
    this.minCenterCoverage = 0.05,
  });

  /// Folder name of the scenario's captures and baselines.
  final String id;

  /// Loads what the scenario needs, then returns the builder of its 3D
  /// view. Called after `Scene.initializeStaticResources()` completed.
  final Future<WidgetBuilder> Function() load;

  /// Whether the four corners must show the background: true for a single
  /// framed object, false for a world that can reach the edges.
  final bool clearCorners;

  /// The smallest share of the frame's middle that must be drawn: a camera
  /// pose that ends between spheres can leave the middle empty.
  final double minCenterCoverage;
}

/// Every scenario the visual tests capture.
final visualScenarios = <VisualScenario>[
  VisualScenario(id: 'sphere', load: () async => _buildSphereScene),
  VisualScenario(
    id: 'sample_start',
    clearCorners: false,
    load: () async {
      final map = await _sampleMap();
      return (context) =>
          CodeWorldView(map: map, touchControls: TouchControlsMode.never);
    },
  ),
  VisualScenario(
    id: 'fly_path',
    clearCorners: false,
    minCenterCoverage: 0,
    load: () async {
      final map = await _sampleMap();
      Widget build(BuildContext context) {
        final world = CodeWorld(map, context.worldColors);
        final navigator = FlyNavigator(world: world);
        flyScriptedPath(navigator);
        world.tick(0, animate: false, cameraPosition: navigator.position);
        return ColoredBox(
          color: world.colors.background,
          child: LayoutBuilder(
            builder: (context, constraints) => SceneView(
              world.scene,
              camera: navigator.camera(constraints.biggest),
            ),
          ),
        );
      }

      return build;
    },
  ),
  _worldScenario(
    'links_top_level',
    pose: _wholeWorld,
    // A whole world is mostly empty space.
    minCenterCoverage: 0.01,
  ),
  _worldScenario(
    'links_focus_selected',
    pose: _wholeWorld,
    selected: 'WeatherRepository',
    minCenterCoverage: 0.01,
  ),
  _worldScenario(
    'inside_interior',
    container: 'WeatherCache',
    pose: _facingChildren,
  ),
  _worldScenario(
    'inside_window',
    container: 'WeatherCache',
    mode: ViewMode.window,
    pose: _lookingOut,
  ),
];

/// The sample world seen from [pose] (chosen from the world and the map),
/// with [mode] and the [selected] node name (links focus on it); the camera
/// is inside [container] (by node name) when given.
VisualScenario _worldScenario(
  String id, {
  required CameraPose Function(CodeWorld world, String? container) pose,
  String? container,
  ViewMode mode = ViewMode.interior,
  String? selected,
  double minCenterCoverage = 0.05,
}) => VisualScenario(
  id: id,
  clearCorners: false,
  minCenterCoverage: minCenterCoverage,
  load: () async {
    final map = await _sampleMap();
    String? idOf(String? name) => name == null
        ? null
        : map.graph.nodes.values.firstWhere((n) => n.name == name).id;
    final containerId = idOf(container);
    final selectedId = idOf(selected);
    Widget build(BuildContext context) {
      final world = CodeWorld(map, context.worldColors)
        ..show(
          resolveVisibility(
            index: VisibilityIndex.of(map),
            containerId: containerId,
            mode: mode,
            linkKinds: {...LinkKind.values},
            selectedId: selectedId,
          ),
          mode,
        );
      final navigator = FlyNavigator(
        world: world,
        start: pose(world, containerId),
      );
      // A capture has no animation: shells at their final opacity, links
      // sized for the camera.
      world.tick(0, animate: false, cameraPosition: navigator.position);
      return ColoredBox(
        color: world.colors.background,
        child: LayoutBuilder(
          builder: (context, constraints) => SceneView(
            world.scene,
            camera: navigator.camera(constraints.biggest),
          ),
        ),
      );
    }

    return build;
  },
);

/// The whole world in view, from the front and a little above.
CameraPose _wholeWorld(CodeWorld world, String? container) => CameraPose(
  position: vm.Vector3(0, world.radius * 0.5, world.radius * 2),
  target: vm.Vector3.zero(),
);

/// Inside [container], above its center, looking out through the shell
/// towards the middle of the world: what window view adds to interior view.
CameraPose _lookingOut(CodeWorld world, String? container) {
  final center = world.positions[container]!;
  final outwards = (vm.Vector3.zero() - center)..normalize();
  final radius = world.map.placements[container]!.radius;
  return CameraPose(
    position:
        center - outwards * (radius * 0.2) + vm.Vector3(0, radius * 0.6, 0),
    target: vm.Vector3.zero(),
  );
}

/// Inside [container], on the side of its shell opposite its children, so
/// they are all ahead of the camera.
CameraPose _facingChildren(CodeWorld world, String? container) {
  final center = world.positions[container]!;
  final children = vm.Vector3.zero();
  for (final child in world.map.graph.childrenOf(container)) {
    children.add(world.positions[child.id]! - center);
  }
  return exitPose(
    world: world,
    target: container,
    from: center - children,
    current: null,
  );
}

Future<CodeMap> _sampleMap() async {
  final bytes = await rootBundle.load(CodeMapSource.sample.path);
  return const CodeMapCodec().decodeFromBytes(Uint8List.sublistView(bytes));
}

/// From the start pose, with a fixed 1/30 s step: forward 1 s (through
/// main()), turn right 45°, forward 0.5 s.
void flyScriptedPath(FlyNavigator navigator) {
  const dt = 1 / 30;
  void fly(double seconds) {
    for (var i = 0; i < (seconds / dt).round(); i++) {
      navigator.step(dt);
    }
  }

  navigator.input.forward = true;
  fly(1);
  navigator.input.forward = false;
  // A drag to the left turns right: 45° at 0.005 rad per pixel.
  navigator
    ..look(const Offset(-(math.pi / 4) / 0.005, 0))
    ..step(dt);
  navigator.input.forward = true;
  fly(0.5);
}

/// A single lit sphere: the renderer smoke test from session 02.
Widget _buildSphereScene(BuildContext context) {
  final material = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.25, 0.55, 0.95, 1)
    ..roughnessFactor = 0.4;
  final scene = Scene()
    ..add(
      Node(name: 'sphere', mesh: Mesh(SphereGeometry(radius: 1), material)),
    );
  return SceneView(
    scene,
    camera: PerspectiveCamera(
      position: vm.Vector3(0, 0.8, -4),
      target: vm.Vector3.zero(),
    ),
  );
}
