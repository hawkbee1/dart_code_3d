// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

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
      'shows the HUD and the touch controls over the 3D area',
      fileName: 'viewer_ready',
      devices: const [GoldenDevice.phone, GoldenDevice.tablet],
      builder: () => viewerViewWith(
        viewerBlocWith(ViewerReady(map: scaleNested(sampleMap()))),
        touchControls: TouchControlsMode.always,
      ),
    );

    goldenTest(
      'shows the HUD without touch controls on desktop',
      fileName: 'viewer_ready',
      devices: const [GoldenDevice.desktop],
      builder: () => viewerViewWith(
        viewerBlocWith(ViewerReady(map: scaleNested(sampleMap()))),
      ),
    );

    // The camera is inside WeatherCache, which has a nested subclass.
    ViewerReady inside(ViewMode mode) {
      final map = scaleNested(sampleMap());
      return ViewerReady(
        map: map,
        currentContainerId: map.graph.nodes.values
            .firstWhere((n) => n.name == 'WeatherCache')
            .id,
        viewMode: mode,
      );
    }

    goldenTest(
      'shows the path, the legend and the view toggle inside a sphere',
      fileName: 'viewer_inside_interior',
      locales: const [Locale('en'), Locale('fr')],
      devices: const [GoldenDevice.phone],
      builder: () => viewerViewWith(
        viewerBlocWith(inside(ViewMode.interior)),
        touchControls: TouchControlsMode.always,
      ),
    );

    goldenTest(
      'shows the window view toggle inside a sphere',
      fileName: 'viewer_inside_window',
      builder: () => viewerViewWith(viewerBlocWith(inside(ViewMode.window))),
    );

    ViewerReady selected(String name, {bool focus = false}) {
      final map = scaleNested(sampleMap());
      return ViewerReady(
        map: map,
        selectedId: map.graph.nodes.values.firstWhere((n) => n.name == name).id,
        focusOnSelected: focus,
      );
    }

    goldenTest(
      'shows the details of the selected class beside the world',
      fileName: 'viewer_selected',
      locales: const [Locale('en'), Locale('fr')],
      builder: () =>
          viewerViewWith(viewerBlocWith(selected('WeatherRepository'))),
    );

    goldenTest(
      'draws only the links of the node it focuses on',
      fileName: 'viewer_selected_focus',
      devices: const [GoldenDevice.tablet],
      themeModes: const [ThemeMode.light],
      builder: () => viewerViewWith(
        viewerBlocWith(selected('WeatherRepository', focus: true)),
      ),
    );

    goldenTest(
      'cuts the very long names of a deep path',
      fileName: 'viewer_long_names',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => viewerViewWith(
        viewerBlocWith(
          ViewerReady(map: longNamesMap(), currentContainerId: 'A.B.C'),
        ),
      ),
    );

    goldenTest(
      'lists the flying controls',
      fileName: 'viewer_controls_help',
      locales: const [Locale('en'), Locale('fr')],
      pump: (tester) async {
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
      },
      builder: () => viewerViewWith(
        viewerBlocWith(ViewerReady(map: scaleNested(sampleMap()))),
      ),
    );
  });
}
