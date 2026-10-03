import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the 3D area for [world], seen through [camera].
typedef CodeWorldSceneBuilder = Widget Function(
  BuildContext context,
  CodeWorld world,
  PerspectiveCamera camera,
);

/// Shows [map] in 3D once flutter_scene's static resources are loaded.
///
/// The [CodeWorld] is rebuilt when the map or the theme colors change.
/// [initialize] and [sceneBuilder] are injectable because widget tests have
/// no GPU context.
class CodeWorldView extends StatefulWidget {
  const new({
    required this.map,
    super.key,
    this.initialize = defaultInitialize,
    this.sceneBuilder = buildCodeWorldScene,
  });

  /// flutter_scene's static resources loader.
  static const Future<void> Function() defaultInitialize =
      Scene.initializeStaticResources;

  /// The code map shown.
  final CodeMap map;

  /// Loads the renderer's shaders and shared resources.
  final Future<void> Function() initialize;

  /// Builds the 3D area once [initialize] has completed.
  final CodeWorldSceneBuilder sceneBuilder;

  @override
  State<CodeWorldView> createState() => _CodeWorldViewState();
}

class _CodeWorldViewState extends State<CodeWorldView> {
  bool _ready = false;
  CodeWorld? _world;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }),
    );
  }

  CodeWorld _worldFor(CodeWorldColors colors) {
    final current = _world;
    if (current != null &&
        identical(current.map, widget.map) &&
        current.colors == colors) {
      return current;
    }
    return _world = CodeWorld(widget.map, colors);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.worldColors;
    if (!_ready) {
      return ColoredBox(
        color: colors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: context.spacing.md),
              Text(context.l10n.viewerPreparingScene),
            ],
          ),
        ),
      );
    }
    final world = _worldFor(colors);
    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) => widget.sceneBuilder(
          context,
          world,
          world.camera(constraints.biggest),
        ),
      ),
    );
  }
}

// coverage:ignore-start
// Needs a GPU context, which `flutter test` does not have; covered by the 3D
// visual tests (integration_test/visual).

/// Draws [world]'s scene through [camera].
Widget buildCodeWorldScene(
  BuildContext context,
  CodeWorld world,
  PerspectiveCamera camera,
) => SceneView(world.scene, camera: camera);

// coverage:ignore-end
