import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/navigation/fly_controls.dart';
import 'package:dart_code_3d/viewer/navigation/fly_navigator.dart';
import 'package:dart_code_3d/viewer/navigation/world_controller.dart';
import 'package:dart_code_3d/viewer/widgets/labels_layer.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:dart_code_3d/viewer/world/picking.dart';
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
    this.selectedId,
    this.labelsOn = true,
    this.touchControls = TouchControlsMode.auto,
    this.hideTouchControls = false,
    this.onContainerChanged,
    this.onSelect,
    this.onToggleViewMode,
    this.onToggleLabels,
    this.onSearch,
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

  /// The selected node, highlighted and named.
  final String? selectedId;

  /// Whether the names of the nearest spheres are drawn.
  final bool labelsOn;

  /// When the on-screen touch controls are shown.
  final TouchControlsMode touchControls;

  /// Whether to hide the touch controls, whatever the setting says.
  final bool hideTouchControls;

  /// Called when the camera enters or leaves a sphere.
  final ValueChanged<String?>? onContainerChanged;

  /// Called with the sphere that was tapped (or is under the crosshair when
  /// `Enter` is pressed), or null for a tap on empty space.
  final ValueChanged<String?>? onSelect;

  /// Switches between interior and window view (the `V` key).
  final VoidCallback? onToggleViewMode;

  /// Shows or hides the labels (the `L` key).
  final VoidCallback? onToggleLabels;

  /// Opens the search (`/` or Ctrl/Cmd+F).
  final VoidCallback? onSearch;

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
    if (current != null) {
      widget.controller?.detach(current);
      current.dispose();
    }
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
    if (navigator != null) {
      widget.controller?.detach(navigator);
      navigator.dispose();
    }
    super.dispose();
  }

  /// The sphere of [world] under [position] in a view of [size], if any.
  String? _pick(
    CodeWorld world,
    FlyNavigator navigator,
    Offset position,
    Size size,
  ) => pickSphere(navigator.viewCamera(size).rayAt(position), world.pickables);

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
    world.select(widget.selectedId);
    final navigator = _navigatorFor(world);
    return ColoredBox(
      color: colors.background,
      child: FlyControls(
        navigator: navigator,
        touchControls: widget.touchControls,
        hideTouchControls: widget.hideTouchControls,
        onHelp: widget.onHelp,
        onToggleViewMode: widget.onToggleViewMode,
        onToggleLabels: widget.onToggleLabels,
        onSearch: widget.onSearch,
        onDeselect: () => widget.onSelect?.call(null),
        onTap: (position, size) =>
            widget.onSelect?.call(_pick(world, navigator, position, size)),
        onSelectCenter: (size) {
          final id = _pick(world, navigator, size.center(Offset.zero), size);
          if (id != null) widget.onSelect?.call(id);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.sceneBuilder(context, world, navigator),
            // Under the labels: a name in the middle is not crossed out.
            const Crosshair(),
            if (widget.labelsOn)
              LabelsLayer(navigator: navigator, world: world),
          ],
        ),
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
