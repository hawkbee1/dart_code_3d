// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

/// A minimap over the sample map, with the camera at the start of the world
/// (or inside [containerName]), as the viewer draws it.
Widget _frame({
  String? containerName,
  String? selectedName,
  bool expanded = true,
}) => Builder(
  builder: (context) {
    final map = sampleMap();
    String? idOf(String? name) => name == null
        ? null
        : map.graph.nodes.values.firstWhere((n) => n.name == name).id;
    final world = CodeWorld(map, context.worldColors);
    final container = idOf(containerName);
    final navigator = FlyNavigator(
      world: world,
      start: container == null
          ? world.startPose
          : exitPose(
              world: world,
              target: container,
              from: world.positions[container]! + Vector3(0.3, 0.4, 1),
              current: null,
            ),
    );
    final controller = WorldController()..attach(navigator);
    return ColoredBox(
      color: context.worldColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: AlignmentDirectional.topEnd,
          child: Minimap(
            map: map,
            containerId: container,
            controller: controller,
            selectedId: idOf(selectedName),
            onSelect: (_) {},
            initiallyExpanded: expanded,
          ),
        ),
      ),
    );
  },
);

void main() {
  group(Minimap, () {
    goldenTest(
      'shows the top level of the sample map with the camera and a selection',
      fileName: 'minimap_top_level',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => _frame(selectedName: 'WeatherRepository'),
    );

    goldenTest(
      'shows what is inside a ghost parent',
      fileName: 'minimap_inside',
      builder: () =>
          _frame(containerName: 'StatelessWidget', selectedName: 'WeatherPage'),
    );

    goldenTest(
      'collapses to its title',
      fileName: 'minimap_collapsed',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      builder: () => _frame(expanded: false),
    );
  });
}
