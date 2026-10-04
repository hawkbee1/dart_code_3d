// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

/// The panel over the world, as in the viewer: a side sheet on wide screens,
/// a bottom sheet on phones.
Widget _frame(NodeDetails details, {bool focusOn = false}) => Builder(
  builder: (context) => ColoredBox(
    color: context.worldColors.background,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final panel = InfoPanel(
          details: details,
          focusOn: focusOn,
          bottomSheet: !wide,
          onFlyTo: () {},
          onEnter: details.isEnterable ? () {} : null,
          onToggleFocus: () {},
          onCopyPath: () {},
          onClose: () {},
        );
        return Stack(
          children: [
            if (wide)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 0,
                width: 360,
                child: panel,
              )
            else
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                height: constraints.maxHeight * 0.6,
                child: panel,
              ),
          ],
        );
      },
    ),
  ),
);

NodeDetails _details(String name) {
  final map = sampleMap();
  return NodeDetails.of(
    map,
    map.graph.nodes.values.firstWhere((n) => n.name == name).id,
  );
}

void main() {
  group(InfoPanel, () {
    goldenTest(
      'describes a class with its links and how far to trust them',
      fileName: 'info_panel_class',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => _frame(_details('WeatherRepository')),
    );

    goldenTest(
      'offers to show all links while focused on one node',
      fileName: 'info_panel_focused',
      themeModes: const [ThemeMode.light],
      builder: () => _frame(_details('WeatherRepository'), focusOn: true),
    );

    goldenTest(
      'describes a method with its location and qualified name',
      fileName: 'info_panel_method',
      builder: () => _frame(_details('locationSearch')),
    );

    goldenTest(
      'describes a ghost parent: the package and what is inside',
      fileName: 'info_panel_ghost',
      builder: () => _frame(_details('Equatable')),
    );

    goldenTest(
      'describes an external package that has no model yet',
      fileName: 'info_panel_external',
      builder: () => _frame(_details('flutter')),
    );

    goldenTest(
      'describes a function',
      fileName: 'info_panel_function',
      builder: () => _frame(_details('main')),
    );

    goldenTest(
      'stays readable with large text',
      fileName: 'info_panel_class',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      textScale: 2,
      builder: () => _frame(_details('WeatherRepository')),
    );

    goldenTest(
      'describes a node without any link',
      fileName: 'info_panel_no_links',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      builder: () => _frame(NodeDetails.of(mapWithoutLinks(), 'A')),
    );
  });
}
