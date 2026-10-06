// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

/// The labels over a blank scene: each one is where the sphere it names would
/// be drawn, projected through the real camera (there is no GPU here).
Widget _frame() => Builder(
  builder: (context) {
    final map = scaleNested(sampleMap());
    final world = CodeWorld(map, context.worldColors);
    final target = map.graph.nodes.values
        .firstWhere((n) => n.name == 'WeatherRepository')
        .id;
    world.select(target);
    final navigator = FlyNavigator(
      world: world,
      start: facingPose(
        world: world,
        target: target,
        from: world.startPose.position,
      ),
    );
    return ColoredBox(
      color: context.worldColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Stand-ins for the spheres, at the same projected places.
          _Spheres(world: world, navigator: navigator),
          LabelsLayer(navigator: navigator, world: world),
          const Crosshair(),
        ],
      ),
    );
  },
);

class _Spheres extends StatelessWidget {
  const new({required this.world, required this.navigator});

  final CodeWorld world;
  final FlyNavigator navigator;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final camera = navigator.viewCamera(constraints.biggest);
      return Stack(
        children: [
          for (final sphere in [
            ...world.content.solid,
            ...world.content.ghosts,
            ...world.content.packages,
          ])
            if (camera.project(sphere.center) case final at?)
              Positioned.fromRect(
                rect: Rect.fromCircle(
                  center: at,
                  radius: camera
                      .screenRadius(sphere.center, sphere.radius)
                      .clamp(2, 600),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context
                        .worldColors
                        .nodes[world.map.graph.nodes[sphere.nodeId]!.kind]!
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

void main() {
  group(LabelsLayer, () {
    goldenTest(
      'names the nearest spheres and rings the selected one',
      fileName: 'labels_layer',
      builder: _frame,
    );
  });
}
