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
];

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
