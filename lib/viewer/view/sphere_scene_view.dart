import 'dart:async';

import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Shows one lit sphere once flutter_scene's static resources are loaded.
///
/// Rendering is gated on [initialize] (`Scene.initializeStaticResources` by
/// default): geometry and materials touch the shader bundle, so the scene is
/// built only after it completes. Both [initialize] and [sceneBuilder] are
/// injectable because plain widget tests have no GPU context.
class SphereSceneView extends StatefulWidget {
  const new({
    super.key,
    this.initialize = Scene.initializeStaticResources,
    this.sceneBuilder = buildSphereScene,
  });

  /// Loads the renderer's shaders and shared resources.
  final Future<void> Function() initialize;

  /// Builds the 3D view once [initialize] has completed.
  final WidgetBuilder sceneBuilder;

  @override
  State<SphereSceneView> createState() => _SphereSceneViewState();
}

class _SphereSceneViewState extends State<SphereSceneView> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.sceneBuilder(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.viewerPreparingScene),
        ],
      ),
    );
  }
}

// coverage:ignore-start
// Needs a GPU context, which `flutter test` does not have; covered by the 3D
// visual tests (integration_test, docs/dart_code_3d session 02).

/// Builds a [SceneView] showing a single lit sphere.
Widget buildSphereScene(BuildContext context) {
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

// coverage:ignore-end
