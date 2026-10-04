import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:material_ui/material_ui.dart';

/// A deterministic 3D scene captured by the visual tests.
///
/// Scenarios must not depend on time: no animation, fixed camera. Later
/// sessions add code-map fixtures and camera poses here.
class VisualScenario {
  const new({required this.id, required this.builder});

  /// Folder name of the scenario's captures and baselines.
  final String id;

  /// Builds the 3D view, after `Scene.initializeStaticResources()` completed.
  final WidgetBuilder builder;
}

/// Every scenario the visual tests capture.
const visualScenarios = <VisualScenario>[
  VisualScenario(id: 'sphere', builder: buildSphereScene),
];
