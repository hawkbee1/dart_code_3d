import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(LinkLegend, () {
    late List<LinkKind> toggled;

    setUp(() => toggled = []);

    // In the viewer, the Scaffold under the HUD provides the Material.
    Widget legend({
      List<LinkKind> kinds = const [LinkKind.call, LinkKind.implementsLink],
      Set<LinkKind> visible = const {LinkKind.call},
    }) => Material(
      child: LinkLegend(
        kinds: kinds,
        visibleKinds: visible,
        onToggle: toggled.add,
      ),
    );

    testWidgets('has a chip per link kind of the map', (tester) async {
      await tester.pumpApp(legend());

      expect(find.byType(FilterChip), findsNWidgets(2));
      expect(find.text('Calls'), findsOneWidget);
      expect(find.text('Implements'), findsOneWidget);
      expect(find.text('Imports'), findsNothing);
    });

    testWidgets('selects the chips of the visible kinds', (tester) async {
      await tester.pumpApp(legend());

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips.map((c) => c.selected), [true, false]);
    });

    testWidgets('shows or hides the kind that is tapped', (tester) async {
      await tester.pumpApp(legend());

      await tester.tap(find.widgetWithText(FilterChip, 'Implements'));
      await tester.tap(find.widgetWithText(FilterChip, 'Calls'));

      expect(toggled, [LinkKind.implementsLink, LinkKind.call]);
    });

    testWidgets('draws each chip dot in its link color', (tester) async {
      await tester.pumpApp(legend());

      final dots = tester.widgetList<Icon>(find.byIcon(Icons.circle));
      expect(dots, hasLength(2));
      expect(dots.map((d) => d.color).toSet(), hasLength(2));
    });

    testWidgets('names every link kind in English and French', (tester) async {
      const english = [
        'Calls',
        'Imports',
        'Implements',
        'Mixins',
        'Extends (external)',
      ];
      const french = [
        'Appels',
        'Imports',
        'Implémentations',
        'Mixins',
        'Étend (externe)',
      ];
      for (final (locale, labels) in [
        (const Locale('en'), english),
        (const Locale('fr'), french),
      ]) {
        await tester.pumpApp(legend(kinds: LinkKind.values), locale: locale);

        for (final label in labels) {
          expect(find.text(label), findsWidgets);
        }
      }
    });

    testWidgets('has tap targets of at least 48 px', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(legend());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
