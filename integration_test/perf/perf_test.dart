// Measures how long code maps take to open (decode + scene build) and the
// frame times of the start view. Run it in profile mode with
// tool/perf_test.sh (repo root of hawkbee); the numbers go to the session
// logs. Software rendering (Xvfb + llvmpipe) gives a lower bound.

import 'dart:io';

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
      final map = await repository.openBytes(bytes);
      decode.stop();
      final build = Stopwatch()..start();
      final world = CodeWorld(map, CodeWorldColors.dark);
      final scene = world.scene;
      build.stop();

      const size = Size(1440, 900);
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> t) => timings.addAll(t);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
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
              child: SceneView(scene, camera: world.camera(size)),
            ),
          ),
        ),
      );
      // Warm up (shaders, first uploads), then measure.
      await tester.pump(const Duration(seconds: 2));
      SchedulerBinding.instance.addTimingsCallback(collect);
      await tester.pump(const Duration(seconds: 5));
      SchedulerBinding.instance.removeTimingsCallback(collect);

      double ms(Iterable<Duration> d) {
        final sorted = d.map((x) => x.inMicroseconds / 1000).toList()..sort();
        return sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];
      }

      double p90(Iterable<Duration> d) {
        final sorted = d.map((x) => x.inMicroseconds / 1000).toList()..sort();
        return sorted.isEmpty ? 0 : sorted[(sorted.length * 0.9).floor()];
      }

      results[name] = {
        'nodes': map.graph.nodes.length,
        'instances': world.instanceCount,
        'decodeMs': decode.elapsedMilliseconds,
        'sceneBuildMs': build.elapsedMilliseconds,
        'frames': timings.length,
        'fps': timings.length / 5,
        'buildMedianMs': ms(timings.map((t) => t.buildDuration)),
        'buildP90Ms': p90(timings.map((t) => t.buildDuration)),
        'rasterMedianMs': ms(timings.map((t) => t.rasterDuration)),
        'rasterP90Ms': p90(timings.map((t) => t.rasterDuration)),
      };
      // The numbers are read from the test log.
      // ignore: avoid_print
      print('PERF $name ${results[name]}');
    });
  }
}
