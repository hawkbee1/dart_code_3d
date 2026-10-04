import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
