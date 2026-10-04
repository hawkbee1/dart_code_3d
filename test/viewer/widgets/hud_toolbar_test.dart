import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(HudToolbar, () {
    late int searched;
    late int toggled;

    setUp(() {
      searched = 0;
      toggled = 0;
    });

    Future<void> pump(
      WidgetTester tester, {
      required bool labelsOn,
      Locale locale = const Locale('en'),
    }) => tester.pumpApp(
      Scaffold(
        body: HudToolbar(
          labelsOn: labelsOn,
          onSearch: () => searched++,
          onToggleLabels: () => toggled++,
        ),
      ),
      locale: locale,
    );

    testWidgets('opens the search', (tester) async {
      await pump(tester, labelsOn: true);

      await tester.tap(find.byTooltip('Search (/)'));

      expect(searched, 1);
    });

    testWidgets('shows or hides the labels', (tester) async {
      await pump(tester, labelsOn: true);

      await tester.tap(find.byTooltip('Labels (L)'));

      expect(toggled, 1);
    });

    testWidgets('shows whether the labels are on', (tester) async {
      await pump(tester, labelsOn: true);
      expect(find.byIcon(Icons.label), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsNothing);

      await pump(tester, labelsOn: false);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, labelsOn: true, locale: const Locale('fr'));

      expect(find.byTooltip('Rechercher (/)'), findsOneWidget);
      expect(find.byTooltip('Étiquettes (L)'), findsOneWidget);
    });

    testWidgets('has big enough buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, labelsOn: true);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
