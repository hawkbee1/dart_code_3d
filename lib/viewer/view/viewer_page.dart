import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:material_ui/material_ui.dart';

/// Temporary viewer: shows a single lit sphere to prove 3D rendering works.
///
/// Session 11 (docs/dart_code_3d) replaces it with the real code map viewer.
class ViewerPage extends StatelessWidget {
  const new({super.key, this.sceneView = const SphereSceneView()});

  /// The 3D area. Injectable so widget tests can avoid the GPU.
  final Widget sceneView;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appTitle)),
      body: sceneView,
    );
  }
}
