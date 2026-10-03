// Ignore for testing purposes
// ignore_for_file: prefer_const_constructors

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('App', () {
    test('shows the ViewerPage by default', () {
      expect(App().home, isA<ViewerPage>());
    });

    testWidgets('renders its home', (tester) async {
      await tester.pumpWidget(App(home: Text('home')));
      expect(find.text('home'), findsOneWidget);
    });
  });
}
