// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';
import '../../helpers/viewer.dart';

/// Advances the indeterminate spinner so it shows an arc, not its
/// first-frame dot.
Future<void> _advanceSpinner(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  group(ViewerView, () {
    goldenTest(
      'shows progress while the map opens',
      fileName: 'viewer_loading',
      pump: _advanceSpinner,
      builder: () => viewerViewWith(viewerBlocWith(const ViewerLoading())),
    );

    goldenTest(
      'explains a file that is not a code map',
      fileName: 'viewer_failure',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => viewerViewWith(
        viewerBlocWith(
          const ViewerFailure(
            'Not a gzip file: the bytes do not start with 1f 8b.',
          ),
        ),
      ),
    );

    goldenTest(
      // The 3D area needs a GPU, so it is blank here; the 3D visual tests
      // (integration_test/visual, sample_start) cover what it draws.
      'shows the HUD over the 3D area',
      fileName: 'viewer_ready',
      builder: () =>
          viewerViewWith(viewerBlocWith(ViewerReady(map: sampleMap()))),
    );
  });
}
