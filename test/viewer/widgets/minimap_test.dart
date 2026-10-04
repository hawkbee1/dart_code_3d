import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(Minimap, () {
    late CodeMap map;
    late WorldController controller;
    late List<String> selected;

    setUp(() {
      map = nestedMap();
      controller = WorldController();
      selected = [];
    });

    tearDown(() => controller.dispose());

    Finder mapArea() => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.size == const Size.square(176),
    );

    Future<void> pump(
      WidgetTester tester, {
      String? containerId,
      String? selectedId,
      bool initiallyExpanded = true,
    }) => tester.pumpApp(
      Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topEnd,
          child: Minimap(
            map: map,
            containerId: containerId,
            controller: controller,
            selectedId: selectedId,
            initiallyExpanded: initiallyExpanded,
            onSelect: selected.add,
          ),
        ),
      ),
    );

    /// Where [id] is on the screen, with the same fit the minimap does: to the
    /// code, not to the packages.
    Offset spot(WidgetTester tester, String id, {String? container}) {
      final positions = cachedWorldPositions(map);
      final spheres = [
        for (final node in map.graph.childrenOf(container))
          (
            id: node.id,
            center: positions[node.id]!,
            radius: map.placements[node.id]!.radius,
          ),
      ];
      final projection = MinimapProjection.fit([
        for (final sphere in spheres)
          if (map.graph.nodes[sphere.id]!.kind != CodeNodeKind.externalPackage)
            sphere,
      ], const Size.square(176));
      final sphere = spheres.firstWhere((s) => s.id == id);
      return tester.getTopLeft(mapArea()) + projection.place(sphere).at;
    }

    testWidgets('is titled and named for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(find.text('Map'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Top-down map of 5 spheres. Tap one to fly to it.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('selects the sphere that is tapped', (tester) async {
      await pump(tester);

      await tester.tapAt(spot(tester, 'C'));
      await tester.tapAt(spot(tester, 'main'));

      expect(selected, ['C', 'main']);
    });

    testWidgets('fits the code, and pins the packages to the edge', (
      tester,
    ) async {
      await pump(tester);

      // The package is 20 units from the code: if the map were fitted to it
      // too, the code would be a speck. Its dot is on the map's edge.
      final package = spot(tester, 'pkg') - tester.getTopLeft(mapArea());
      expect(package.dx, closeTo(4, 1e-6));
      await tester.tapAt(spot(tester, 'pkg'));

      expect(selected, ['pkg']);
    });

    testWidgets('fits the packages when they are all there is', (tester) async {
      map = onlyPackageMap();
      await pump(tester);

      await tester.tapAt(tester.getCenter(mapArea()));

      expect(selected, ['pkg']);
    });

    testWidgets('picks the smallest of spheres seen one above the other', (
      tester,
    ) async {
      // A and G are at the same x and z, one above the other: A is smaller.
      await pump(tester);

      await tester.tapAt(spot(tester, 'G'));

      expect(selected, ['A']);
    });

    testWidgets('ignores taps on empty space', (tester) async {
      await pump(tester);

      await tester.tapAt(tester.getTopLeft(mapArea()) + const Offset(3, 170));

      expect(selected, isEmpty);
    });

    testWidgets('shows what is inside the container the camera is in', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, containerId: 'A');

      // A holds a method and a nested class.
      expect(find.bySemanticsLabel(RegExp('map of 2 spheres')), findsOneWidget);
      handle.dispose();
      await tester.tapAt(spot(tester, 'A.B', container: 'A'));

      expect(selected, ['A.B']);
    });

    testWidgets('collapses to its title and expands again', (tester) async {
      await pump(tester);
      expect(mapArea(), findsOneWidget);

      await tester.tap(find.byTooltip('Hide the map'));
      await tester.pump();
      expect(mapArea(), findsNothing);
      expect(find.text('Map'), findsOneWidget);

      await tester.tap(find.byTooltip('Show the map'));
      await tester.pump();
      expect(mapArea(), findsOneWidget);
    });

    testWidgets('can start collapsed', (tester) async {
      await pump(tester, initiallyExpanded: false);

      expect(mapArea(), findsNothing);
      expect(find.byTooltip('Show the map'), findsOneWidget);
    });

    group('selection', () {
      testWidgets('rings a selected sphere, or the one that holds it', (
        tester,
      ) async {
        for (final id in ['C', 'A.B.n', null]) {
          await pump(tester, selectedId: id);

          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('has nothing to ring when the selection is elsewhere', (
        tester,
      ) async {
        // Inside A: C is not on the map and has no parent on it either.
        await pump(tester, containerId: 'A', selectedId: 'C');

        expect(tester.takeException(), isNull);
        expect(mapArea(), findsOneWidget);
      });

      testWidgets('has nothing to ring for a node that is not in the map', (
        tester,
      ) async {
        await pump(tester, selectedId: 'unknown');

        expect(tester.takeException(), isNull);
      });
    });

    group('the camera', () {
      late CodeWorld world;

      setUp(() => world = CodeWorld(map, CodeWorldColors.light));

      testWidgets('is drawn, and follows it when it moves', (tester) async {
        final navigator = FlyNavigator(world: world);
        controller.attach(navigator);
        await pump(tester);

        navigator
          ..input.forward = true
          ..step(1 / 30);
        await tester.pump();

        expect(tester.takeException(), isNull);
        navigator.dispose();
      });

      testWidgets('is drawn when looking straight up', (tester) async {
        final navigator = FlyNavigator(
          world: world,
          start: CameraPose(
            position: Vector3(0, 5, 0),
            target: Vector3(0, 10, 0),
          ),
        );
        controller.attach(navigator);
        await pump(tester);

        expect(tester.takeException(), isNull);
        navigator.dispose();
      });

      testWidgets('stays on the map when far outside it', (tester) async {
        final navigator = FlyNavigator(
          world: world,
          start: CameraPose(
            position: Vector3(900, 0, 900),
            target: Vector3.zero(),
          ),
        );
        controller.attach(navigator);
        await pump(tester);

        expect(tester.takeException(), isNull);
        navigator.dispose();
      });
    });

    testWidgets('redraws only when something changed', (tester) async {
      await pump(tester, selectedId: 'C');
      await pump(tester, selectedId: 'C');
      await pump(tester, selectedId: 'A');

      expect(tester.takeException(), isNull);
      expect(mapArea(), findsOneWidget);
    });

    testWidgets('has big enough buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
