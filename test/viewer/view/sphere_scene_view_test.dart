// Ignore for testing purposes
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SphereSceneView', () {
    // Created inside each test body (not in setUp) so the completion runs in
    // the test's fake-async zone and `pump` delivers it.
    late Completer<void> initialization;

    Widget buildSubject() {
      initialization = Completer<void>();
      return SphereSceneView(
        initialize: () => initialization.future,
        sceneBuilder: (_) => Text('scene ready'),
      );
    }

    test('defaults to flutter_scene initialization and the sphere scene', () {
      final view = SphereSceneView();
      expect(view.initialize, equals(Scene.initializeStaticResources));
      expect(view.sceneBuilder, equals(buildSphereScene));
    });

    testWidgets('shows a progress message until the renderer is ready', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Preparing the 3D scene…'), findsOneWidget);
      expect(find.text('scene ready'), findsNothing);
    });

    testWidgets('builds the scene once the renderer is ready', (tester) async {
      await tester.pumpApp(buildSubject());

      initialization.complete();
      await tester.pump();

      expect(find.text('scene ready'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('does not update after being disposed', (tester) async {
      await tester.pumpApp(buildSubject());
      await tester.pumpApp(SizedBox());

      initialization.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
