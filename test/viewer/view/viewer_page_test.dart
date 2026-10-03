// Ignore for testing purposes
// ignore_for_file: prefer_const_constructors

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ViewerPage', () {
    test('uses a SphereSceneView by default', () {
      expect(ViewerPage().sceneView, isA<SphereSceneView>());
    });

    testWidgets('shows the app title and the scene area', (tester) async {
      await tester.pumpApp(
        ViewerPage(sceneView: Text('scene', key: Key('scene'))),
      );
      expect(find.text('dart_code_3D'), findsOneWidget);
      expect(find.byKey(Key('scene')), findsOneWidget);
    });
  });
}
