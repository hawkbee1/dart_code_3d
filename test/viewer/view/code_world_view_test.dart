import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

class _SpyController extends WorldController {
  final attached = <FlyNavigator>[];
  final detached = <FlyNavigator>[];

  @override
  void attach(FlyNavigator navigator) {
    attached.add(navigator);
    super.attach(navigator);
  }

  @override
  void detach(FlyNavigator navigator) {
    detached.add(navigator);
    super.detach(navigator);
  }
}

void main() {
  group(CodeWorldView, () {
    late List<(CodeWorld, FlyNavigator)> built;

    setUp(() => built = []);

    Widget scene(BuildContext context, CodeWorld world, FlyNavigator n) {
      built.add((world, n));
      return Text('${world.instanceCount} spheres');
    }

    test('loads flutter_scene resources by default', () {
      expect(
        CodeWorldView(map: worldMap()).initialize,
        CodeWorldView.defaultInitialize,
      );
      expect(CodeWorldView(map: worldMap()).sceneBuilder, buildCodeWorldScene);
    });

    testWidgets('waits for the renderer before building the world', (
      tester,
    ) async {
      final initialization = Completer<void>();
      await tester.pumpApp(
        CodeWorldView(
          map: worldMap(),
          initialize: () => initialization.future,
          sceneBuilder: scene,
        ),
      );

      expect(find.text('Preparing the 3D scene…'), findsOneWidget);
      expect(built, isEmpty);

      initialization.complete();
      await tester.pump();

      expect(find.text('3 spheres'), findsOneWidget);
      final (world, navigator) = built.single;
      expect(world.colors, CodeWorldColors.light);
      expect(navigator.position, world.startPose.position);
    });

    testWidgets('keeps the world until the map or the colors change', (
      tester,
    ) async {
      final map = worldMap();
      Future<void> pump(ThemeMode mode, {required CodeMap map}) =>
          tester.pumpApp(
            CodeWorldView(
              map: map,
              initialize: () async {},
              sceneBuilder: scene,
            ),
            themeMode: mode,
          );

      await pump(ThemeMode.light, map: map);
      await tester.pump();
      await pump(ThemeMode.light, map: map);
      await pump(ThemeMode.dark, map: map);
      await tester.pumpAndSettle();
      await pump(ThemeMode.dark, map: worldMap());

      final worlds = built.map((b) => b.$1).toSet();
      expect(worlds.first.colors, CodeWorldColors.light);
      expect(worlds.any((w) => w.colors == CodeWorldColors.dark), isTrue);
      expect(identical(built[0].$1, built[1].$1), isTrue);
      expect(identical(built.last.$1.map, map), isFalse);
    });

    group('visible world', () {
      testWidgets('is shown by the world', (tester) async {
        final map = nestedMap();
        final visible = resolveVisibility(
          index: VisibilityIndex.of(map),
          containerId: 'A',
          mode: ViewMode.window,
          linkKinds: {...LinkKind.values},
        );
        await tester.pumpApp(
          CodeWorldView(
            map: map,
            visible: visible,
            viewMode: ViewMode.window,
            initialize: () async {},
            sceneBuilder: scene,
          ),
        );
        await tester.pump();

        final (world, _) = built.last;
        expect(world.containerId, 'A');
        expect(world.instanceCount, visible.visibleSpheres.length);
      });

      testWidgets('is kept when the theme changes', (tester) async {
        final map = nestedMap();
        final visible = resolveVisibility(
          index: VisibilityIndex.of(map),
          containerId: 'A',
          mode: ViewMode.interior,
          linkKinds: {...LinkKind.values},
        );
        Future<void> pump(ThemeMode mode) => tester.pumpApp(
          CodeWorldView(
            map: map,
            visible: visible,
            initialize: () async {},
            sceneBuilder: scene,
          ),
          themeMode: mode,
        );

        await pump(ThemeMode.light);
        await tester.pump();
        await pump(ThemeMode.dark);
        await tester.pumpAndSettle();

        final (world, _) = built.last;
        expect(world.colors, CodeWorldColors.dark);
        expect(world.containerId, 'A');
      });
    });

    group('controller', () {
      testWidgets('gets the navigator and lets go of it', (tester) async {
        final controller = _SpyController();
        await tester.pumpApp(
          CodeWorldView(
            map: worldMap(),
            controller: controller,
            initialize: () async {},
            sceneBuilder: scene,
          ),
        );
        await tester.pump();
        expect(controller.attached, [built.last.$2]);

        await tester.pumpApp(const SizedBox());

        expect(controller.detached, [built.last.$2]);
      });

      testWidgets('follows a change of controller', (tester) async {
        final map = worldMap();
        final first = _SpyController();
        final second = _SpyController();
        Future<void> pump(WorldController controller) => tester.pumpApp(
          CodeWorldView(
            map: map,
            controller: controller,
            initialize: () async {},
            sceneBuilder: scene,
          ),
        );

        await pump(first);
        await tester.pump();
        await pump(second);

        final navigator = built.last.$2;
        expect(first.detached, [navigator]);
        expect(second.attached, [navigator]);
      });

      testWidgets('moves to a new navigator with a new map', (tester) async {
        final controller = _SpyController();
        Future<void> pump(CodeMap map) => tester.pumpApp(
          CodeWorldView(
            map: map,
            controller: controller,
            initialize: () async {},
            sceneBuilder: scene,
          ),
        );

        await pump(worldMap());
        await tester.pump();
        final before = built.last.$2;
        await pump(nestedMap());

        final after = built.last.$2;
        expect(after, isNot(same(before)));
        expect(controller.detached, [before]);
        expect(controller.attached, [before, after]);
      });
    });

    group('selecting', () {
      late CodeMap map;
      late List<String?> selections;
      const view = Size(800, 600);

      setUp(() {
        map = worldMap();
        selections = [];
      });

      Future<void> pumpSelecting(
        WidgetTester tester, {
        String? selectedId,
        bool labelsOn = true,
        VoidCallback? onToggleLabels,
        VoidCallback? onSearch,
      }) async {
        await tester.pumpApp(
          CodeWorldView(
            map: map,
            initialize: () async {},
            sceneBuilder: scene,
            selectedId: selectedId,
            labelsOn: labelsOn,
            onSelect: selections.add,
            onToggleLabels: onToggleLabels,
            onSearch: onSearch,
          ),
        );
        await tester.pump();
      }

      Offset on(String id) =>
          built.last.$2.viewCamera(view).project(built.last.$1.positions[id]!)!;

      testWidgets('selects the sphere that is tapped', (tester) async {
        await pumpSelecting(tester);

        await tester.tapAt(on('main'));
        await tester.tapAt(on('A'));

        expect(selections, ['main', 'A']);
      });

      testWidgets('deselects on a tap in empty space', (tester) async {
        await pumpSelecting(tester);

        await tester.tapAt(const Offset(10, 10));

        expect(selections, [null]);
      });

      testWidgets('Enter selects what is under the crosshair', (tester) async {
        await pumpSelecting(tester);

        // The camera starts out looking at main().
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

        expect(selections, ['main']);
      });

      testWidgets('Enter selects nothing when nothing is in the middle', (
        tester,
      ) async {
        await pumpSelecting(tester);
        built.last.$2
          ..look(const Offset(300, 0))
          ..step(1 / 30);
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

        expect(selections, isEmpty);
      });

      testWidgets('Esc deselects', (tester) async {
        await pumpSelecting(tester, selectedId: 'A');

        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

        expect(selections, [null]);
      });

      testWidgets('highlights the selected node in the world', (tester) async {
        await pumpSelecting(tester, selectedId: 'A');

        expect(built.last.$1.selectedId, 'A');
        expect(built.last.$1.highlighted!.nodeId, 'A');
      });

      testWidgets('keeps the selection when the theme changes', (tester) async {
        await pumpSelecting(tester, selectedId: 'A');
        await tester.pumpApp(
          CodeWorldView(
            map: map,
            initialize: () async {},
            sceneBuilder: scene,
            selectedId: 'A',
          ),
          themeMode: ThemeMode.dark,
        );
        // The theme (and its extensions) animate to the new one.
        await tester.pumpAndSettle();

        expect(built.last.$1.colors, CodeWorldColors.dark);
        expect(built.last.$1.selectedId, 'A');
      });

      testWidgets('draws the labels and the crosshair, or only the crosshair', (
        tester,
      ) async {
        await pumpSelecting(tester);
        expect(find.byType(LabelsLayer), findsOneWidget);
        expect(find.byType(Crosshair), findsOneWidget);

        await pumpSelecting(tester, labelsOn: false);
        expect(find.byType(LabelsLayer), findsNothing);
        expect(find.byType(Crosshair), findsOneWidget);
      });

      testWidgets('forwards the L key and the search keys', (tester) async {
        var labels = 0;
        var searches = 0;
        await pumpSelecting(
          tester,
          onToggleLabels: () => labels++,
          onSearch: () => searches++,
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '/');
        await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);

        expect(labels, 1);
        expect(searches, 1);
      });

      testWidgets('can hide the touch controls', (tester) async {
        await tester.pumpApp(
          CodeWorldView(
            map: map,
            initialize: () async {},
            sceneBuilder: scene,
            touchControls: TouchControlsMode.always,
            hideTouchControls: true,
          ),
        );
        await tester.pump();

        expect(find.byType(Trackball), findsNothing);
      });
    });

    testWidgets('forwards the V key', (tester) async {
      var toggled = 0;
      await tester.pumpApp(
        CodeWorldView(
          map: worldMap(),
          initialize: () async {},
          sceneBuilder: scene,
          onToggleViewMode: () => toggled++,
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);

      expect(toggled, 1);
    });

    testWidgets('does not build after being removed', (tester) async {
      final initialization = Completer<void>();
      await tester.pumpApp(
        CodeWorldView(
          map: worldMap(),
          initialize: () => initialization.future,
          sceneBuilder: scene,
        ),
      );
      await tester.pumpApp(const SizedBox());

      initialization.complete();
      await tester.pump();

      expect(built, isEmpty);
    });
  });
}
