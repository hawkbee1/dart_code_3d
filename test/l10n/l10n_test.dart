import 'dart:async';

import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AppLocalizations', () {
    test('supports English and French only', () {
      expect(AppLocalizations.supportedLocales, const [
        Locale('en'),
        Locale('fr'),
      ]);
    });

    testWidgets('shows French strings for the fr locale', (tester) async {
      final initialization = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SphereSceneView(initialize: () => initialization.future),
        ),
      );

      expect(find.text('Préparation de la scène 3D…'), findsOneWidget);
    });
  });
}
