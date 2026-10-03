import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A deterministic 3D scene captured by the visual tests.
///
/// Scenarios must not depend on time: no animation, fixed camera.
class VisualScenario {
  const new({required this.id, required this.load, this.clearCorners = true});

  /// Folder name of the scenario's captures and baselines.
  final String id;

  /// Loads what the scenario needs, then returns the builder of its 3D
  /// view. Called after `Scene.initializeStaticResources()` completed.
  final Future<WidgetBuilder> Function() load;

  /// Whether the four corners must show the background: true for a single
  /// framed object, false for a world that can reach the edges.
  final bool clearCorners;
}

/// Every scenario the visual tests capture.
final visualScenarios = <VisualScenario>[
  VisualScenario(id: 'sphere', load: () async => _buildSphereScene),
  VisualScenario(
    id: 'sample_start',
    clearCorners: false,
    load: () async {
      final bytes = await rootBundle.load(CodeMapSource.sample.path);
      final map = const CodeMapCodec().decodeFromBytes(
        Uint8List.sublistView(bytes),
      );
      return (context) => CodeWorldView(map: map);
    },
  ),
];

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
