import 'dart:ui' show FrameTiming, TimingsCallback;

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

FrameTiming _frame(int startUs, {int buildUs = 4000, int rasterUs = 6000}) =>
    FrameTiming(
      vsyncStart: startUs,
      buildStart: startUs,
      buildFinish: startUs + buildUs,
      rasterStart: startUs + buildUs,
      rasterFinish: startUs + buildUs + rasterUs,
      rasterFinishWallTime: startUs + buildUs + rasterUs,
    );

void main() {
  group(DebugOverlay, () {
    late List<TimingsCallback> added;
    late List<TimingsCallback> removed;

    setUp(() {
      added = [];
      removed = [];
    });

    Widget overlay() => DebugOverlay(
      instanceCount: 42,
      linkCount: 7,
      addTimingsCallback: added.add,
      removeTimingsCallback: removed.add,
    );

    testWidgets('waits for frames, then shows the frame statistics', (
      tester,
    ) async {
      await tester.pumpApp(overlay());
      expect(find.textContaining('waiting for frames'), findsOneWidget);
      expect(find.textContaining('42 spheres · 7 links'), findsOneWidget);

      // 61 frames 1/60 s apart: 60 fps.
      added.single([for (var i = 0; i <= 60; i++) _frame(i * 16667)]);
      await tester.pump();

      final text = tester.widget<Text>(find.textContaining('fps')).data;
      expect(text, contains('60 fps'), reason: text);
      expect(find.textContaining('build 4.0 ms'), findsOneWidget);
      expect(find.textContaining('raster 6.0 ms'), findsOneWidget);
    });

    testWidgets('keeps only the latest frames', (tester) async {
      await tester.pumpApp(overlay());

      added.single([for (var i = 0; i < 100; i++) _frame(i, buildUs: 1000)]);
      added.single([for (var i = 0; i < 120; i++) _frame(1000000 + i * 16667)]);
      await tester.pump();

      expect(find.textContaining('build 4.0 ms'), findsOneWidget);
    });

    testWidgets('shows 0 fps for frames without duration', (tester) async {
      await tester.pumpApp(overlay());

      added.single([
        FrameTiming(
          vsyncStart: 10,
          buildStart: 10,
          buildFinish: 10,
          rasterStart: 10,
          rasterFinish: 10,
          rasterFinishWallTime: 10,
        ),
        _frame(0, buildUs: 0, rasterUs: 0),
      ]);
      await tester.pump();

      expect(find.textContaining('0 fps'), findsOneWidget);
    });

    testWidgets('unregisters when removed and ignores late timings', (
      tester,
    ) async {
      await tester.pumpApp(overlay());
      await tester.pumpApp(const SizedBox());

      expect(removed, added);
      added.single([_frame(0), _frame(16667)]);
    });

    testWidgets('uses the scheduler by default', (tester) async {
      await tester.pumpApp(const DebugOverlay(instanceCount: 1, linkCount: 0));
      await tester.pumpApp(const SizedBox());

      expect(tester.takeException(), isNull);
    });
  });
}
