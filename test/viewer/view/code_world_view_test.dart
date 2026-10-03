import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

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
