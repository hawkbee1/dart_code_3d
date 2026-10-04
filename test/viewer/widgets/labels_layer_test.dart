import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(LabelsLayer, () {
    late CodeWorld world;
    late FlyNavigator navigator;

    // The start pose looks at `main` from 4.5 units away: `main` is in the
    // middle of the view, class A to its right, the package far to the left.
    setUp(() {
      world = CodeWorld(worldMap(), CodeWorldColors.light);
      navigator = FlyNavigator(world: world);
    });

    Future<void> pump(
      WidgetTester tester, {
      int maxLabels = 25,
      double textScale = 1,
    }) => tester.pumpApp(
      Stack(
        fit: StackFit.expand,
        children: [
          LabelsLayer(navigator: navigator, world: world, maxLabels: maxLabels),
        ],
      ),
      textScale: textScale,
    );

    testWidgets('names the spheres in front of the camera', (tester) async {
      await pump(tester);

      expect(find.text('main'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      // The package is far to the left, outside the view.
      expect(find.text('http'), findsNothing);
    });

    testWidgets('puts a name over the middle of its sphere', (tester) async {
      await pump(tester);

      final expected = navigator
          .viewCamera(const Size(800, 600))
          .project(world.positions['main']!)!;
      final label = tester.getCenter(find.text('main'));

      expect(label.dx, closeTo(expected.dx, 1));
      expect(label.dy, closeTo(expected.dy, 1));
    });

    testWidgets('follows the camera when it turns', (tester) async {
      await pump(tester);
      expect(find.text('http'), findsNothing);

      // About 54° to the left (0.005 rad per pixel): now the package is
      // ahead, and class A is out of the view.
      navigator
        ..look(const Offset(188, 0))
        ..step(1 / 30);
      await tester.pump();

      expect(find.text('http'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('keeps only the nearest names', (tester) async {
      await pump(tester, maxLabels: 1);

      expect(find.text('main'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('circles the name of the selected sphere', (tester) async {
      world.select('A');
      await pump(tester);

      Border? borderOf(String text) =>
          (tester
                          .widget<DecoratedBox>(
                            find
                                .ancestor(
                                  of: find.text(text),
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border?;

      expect(borderOf('A')?.top.color, CodeWorldColors.light.selection);
      expect(borderOf('main'), isNull);
    });

    testWidgets('names the sphere that holds a hidden selection', (
      tester,
    ) async {
      world.select('A.m');
      await pump(tester);

      final border =
          (tester
                          .widget<DecoratedBox>(
                            find
                                .ancestor(
                                  of: find.text('A'),
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border?;
      expect(border?.top.color, CodeWorldColors.light.selection);
    });

    testWidgets('measures again when the text gets bigger', (tester) async {
      await pump(tester);
      final small = tester.getSize(
        find
            .ancestor(
              of: find.text('main'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      await pump(tester, textScale: 2);
      await tester.pump();
      final big = tester.getSize(
        find
            .ancestor(
              of: find.text('main'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      expect(big.width, greaterThan(small.width));
    });

    testWidgets('lets taps through to the view below', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(onTap: () => taps++),
            LabelsLayer(navigator: navigator, world: world),
          ],
        ),
      );

      await tester.tapAt(tester.getCenter(find.text('main')));

      expect(taps, 1);
    });
  });

  group(Crosshair, () {
    testWidgets('sits in the middle of the view', (tester) async {
      await tester.pumpApp(
        const Stack(fit: StackFit.expand, children: [Crosshair()]),
      );

      final center = tester.getCenter(find.byType(Crosshair));
      expect(center, const Offset(400, 300));
    });

    testWidgets('follows the theme', (tester) async {
      await tester.pumpApp(const Crosshair());
      await tester.pumpApp(const Crosshair(), themeMode: ThemeMode.dark);
      await tester.pumpApp(const Crosshair(), themeMode: ThemeMode.dark);

      expect(tester.takeException(), isNull);
    });

    testWidgets('lets taps through', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(onTap: () => taps++),
            const Crosshair(),
          ],
        ),
      );

      await tester.tapAt(const Offset(400, 300));

      expect(taps, 1);
      expect(SystemChannels.platform, isNotNull);
    });
  });
}
