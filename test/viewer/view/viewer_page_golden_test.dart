// goldenTest tags every test with TestTag.golden. (A library-level
// `@Tags([TestTag.golden])` does not work: the runner only accepts string
// literals there.)

import 'dart:async';

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

/// Advances the indeterminate spinner so it shows an arc, not its
/// first-frame dot.
Future<void> _advanceSpinner(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  group(ViewerPage, () {
    goldenTest(
      'shows the progress message while the renderer loads',
      fileName: 'viewer_page_loading',
      pump: _advanceSpinner,
      // Never completes: the page stays in its loading state.
      builder: () => ViewerPage(
        sceneView: SphereSceneView(initialize: () => Completer<void>().future),
      ),
    );

    goldenTest(
      'shows the progress message in French',
      fileName: 'viewer_page_loading',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      locales: const [Locale('fr')],
      pump: _advanceSpinner,
      builder: () => ViewerPage(
        sceneView: SphereSceneView(initialize: () => Completer<void>().future),
      ),
    );

    goldenTest(
      // The 3D area itself needs a GPU, so it is blank here; the 3D visual
      // tests (integration_test/visual) cover what it draws.
      'shows the app bar around the 3D area once ready',
      fileName: 'viewer_page_ready',
      builder: () => const ViewerPage(sceneView: SizedBox.expand()),
    );
  });
}
