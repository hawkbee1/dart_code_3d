// Measures how long code maps take to open (decode + scene build) and the
// frame times of the start view. Run it in profile mode with
// tool/perf_test.sh (repo root of hawkbee); the numbers go to the session
// logs. Software rendering (Xvfb + llvmpipe) gives a lower bound.

import 'dart:io';

import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:code_source_client/code_source_client.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

/// Extra `.dc3d` files to measure, comma separated.
const _maps = String.fromEnvironment('DC3D_PERF_MAPS');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final results = <String, Object?>{};

  tearDownAll(() => binding.reportData = {'perf': results});

  final sources = <String, Future<Uint8List> Function()>{
    'sample': () async =>
        Uint8List.sublistView(await rootBundle.load(CodeMapSource.sample.path)),
    for (final path in _maps.split(',').where((p) => p.isNotEmpty))
      path.split('/').last: () => File(path).readAsBytes(),
  };

  for (final MapEntry(key: name, value: read) in sources.entries) {
    testWidgets('$name opens and renders', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Scene.initializeStaticResources();
      final repository = CodeMapRepository(
        sourceClient: CodeSourceClient(),
        store: InMemoryCodeMapStore(),
      );

      final bytes = await read();
      final decode = Stopwatch()..start();
      final map = scaleNested(await repository.openBytes(bytes));
      decode.stop();
      final build = Stopwatch()..start();
      final world = CodeWorld(map, CodeWorldColors.dark);
      final scene = world.scene;
      build.stop();

      const size = Size(1440, 900);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      double ms(Iterable<Duration> d) {
        final sorted = d.map((x) => x.inMicroseconds / 1000).toList()..sort();
        return sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];
      }

      double p90(Iterable<Duration> d) {
        final sorted = d.map((x) => x.inMicroseconds / 1000).toList()..sort();
        return sorted.isEmpty ? 0 : sorted[(sorted.length * 0.9).floor()];
      }

      /// Draws [scene] from [camera] for a while and reads the frame times.
      Future<Map<String, Object?>> measure(
        Scene scene,
        PerspectiveCamera camera,
      ) async {
        final timings = <FrameTiming>[];
        void collect(List<FrameTiming> t) => timings.addAll(t);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: SizedBox.fromSize(
                size: size,
                child: SceneView(scene, camera: camera),
              ),
            ),
          ),
        );
        // Warm up (shaders, first uploads), then measure.
        await tester.pump(const Duration(seconds: 2));
        SchedulerBinding.instance.addTimingsCallback(collect);
        await tester.pump(const Duration(seconds: 5));
        SchedulerBinding.instance.removeTimingsCallback(collect);
        return {
          'frames': timings.length,
          'fps': timings.length / 5,
          'buildMedianMs': ms(timings.map((t) => t.buildDuration)),
          'buildP90Ms': p90(timings.map((t) => t.buildDuration)),
          'rasterMedianMs': ms(timings.map((t) => t.rasterDuration)),
          'rasterP90Ms': p90(timings.map((t) => t.rasterDuration)),
        };
      }

      final topLevel = await measure(scene, world.camera(size));
      results[name] = {
        'nodes': map.graph.nodes.length,
        'instances': world.instanceCount,
        'decodeMs': decode.elapsedMilliseconds,
        'sceneBuildMs': build.elapsedMilliseconds,
        ...topLevel,
      };

      // Inside the sphere that holds the most members: the busiest view.
      final largest = map.graph.nodes.values
          .where((n) => n.kind != CodeNodeKind.externalPackage)
          .map((n) => (id: n.id, children: map.graph.childrenOf(n.id).length))
          .reduce((a, b) => a.children >= b.children ? a : b);
      if (largest.children > 0) {
        final navigator = FlyNavigator(world: world)
          ..flyTo(
            exitPose(
              world: world,
              target: largest.id,
              from: world.startPose.position,
              current: null,
            ),
            animate: false,
          );
        final inside = ViewerReady(
          map: map,
          currentContainerId: navigator.container,
        );
        final show = Stopwatch()..start();
        world
          ..show(inside.visible, inside.viewMode)
          ..tick(0, animate: false, cameraPosition: navigator.position);
        show.stop();
        results[name] = {
          ...results[name]! as Map<String, Object?>,
          'inside': {
            'container': map.graph.nodes[largest.id]!.name,
            'children': largest.children,
            'visibleSpheres': inside.visible.visibleSpheres.length,
            'links': inside.visible.links.length,
            'showMs': show.elapsedMilliseconds,
            ...await measure(world.scene, navigator.camera(size)),
          },
        };
      }
      // The numbers are read from the test log.
      // ignore: avoid_print
      print('PERF $name ${results[name]}');
    });
  }
}
