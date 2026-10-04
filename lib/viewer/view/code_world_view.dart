import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/navigation/fly_controls.dart';
import 'package:dart_code_3d/viewer/navigation/fly_navigator.dart';
import 'package:dart_code_3d/viewer/navigation/world_controller.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:dart_code_3d/viewer/world/visibility.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

/// Builds the 3D area for [world], seen from [navigator]'s camera.
typedef CodeWorldSceneBuilder = Widget Function(
  BuildContext context,
  CodeWorld world,
  FlyNavigator navigator,
);

/// Shows [map] in 3D once flutter_scene's static resources are loaded, and
/// lets the user fly through it.
///
/// The [CodeWorld] is rebuilt when the map or the theme colors change; the
/// [FlyNavigator] (the camera) only when the map changes.
/// [initialize] and [sceneBuilder] are injectable because widget tests have
/// no GPU context.
class CodeWorldView extends StatefulWidget {
  const new({
    required this.map,
    super.key,
    this.initialize = defaultInitialize,
    this.sceneBuilder = buildCodeWorldScene,
    this.visible,
    this.viewMode = ViewMode.interior,
    this.controller,
    this.touchControls = TouchControlsMode.auto,
    this.onContainerChanged,
    this.onToggleViewMode,
    this.onHelp,
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

  /// What is visible (the top level when null): the spheres, links and
  /// shells to draw.
  final VisibleWorld? visible;

  /// Interior or window view, for the shell of the current container.
  final ViewMode viewMode;

  /// Moves the camera on behalf of the HUD.
  final WorldController? controller;

  /// When the on-screen touch controls are shown.
  final TouchControlsMode touchControls;

  /// Called when the camera enters or leaves a sphere.
  final ValueChanged<String?>? onContainerChanged;

  /// Switches between interior and window view (the `V` key).
  final VoidCallback? onToggleViewMode;

  /// Shows the controls help (the `?` key).
  final VoidCallback? onHelp;

  @override
  State<CodeWorldView> createState() => _CodeWorldViewState();
}

class _CodeWorldViewState extends State<CodeWorldView> {
  bool _ready = false;
  CodeWorld? _world;
  FlyNavigator? _navigator;

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

  FlyNavigator _navigatorFor(CodeWorld world) {
    final current = _navigator;
    if (current != null && identical(current.world.map, world.map)) {
      return current;
    }
    if (current != null) widget.controller?.detach(current);
    final navigator = FlyNavigator(
      world: world,
      onContainerChanged: (id) => widget.onContainerChanged?.call(id),
    );
    widget.controller?.attach(navigator);
    return _navigator = navigator;
  }

  @override
  void didUpdateWidget(CodeWorldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final navigator = _navigator;
    if (navigator != null && oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(navigator);
      widget.controller?.attach(navigator);
    }
  }

  @override
  void dispose() {
    final navigator = _navigator;
    if (navigator != null) widget.controller?.detach(navigator);
    super.dispose();
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
    final visible = widget.visible;
    if (visible != null) world.show(visible, widget.viewMode);
    final navigator = _navigatorFor(world);
    return ColoredBox(
      color: colors.background,
      child: FlyControls(
        navigator: navigator,
        touchControls: widget.touchControls,
        onHelp: widget.onHelp,
        onToggleViewMode: widget.onToggleViewMode,
        child: widget.sceneBuilder(context, world, navigator),
      ),
    );
  }
}

// coverage:ignore-start
// Needs a GPU context, which `flutter test` does not have; covered by the 3D
// visual tests (integration_test/visual).

/// Draws [world]'s scene from [navigator]'s camera, stepping the flight
/// every frame.
Widget buildCodeWorldScene(
  BuildContext context,
  CodeWorld world,
  FlyNavigator navigator,
) => LayoutBuilder(
  builder: (context, constraints) => SceneView(
    world.scene,
    cameraBuilder: (_) => navigator.camera(constraints.biggest),
    onTick: (_, deltaSeconds) {
      navigator.step(deltaSeconds);
      world.tick(
        deltaSeconds,
        animate: !MediaQuery.disableAnimationsOf(context),
        cameraPosition: navigator.position,
      );
    },
  ),
);

// coverage:ignore-end
