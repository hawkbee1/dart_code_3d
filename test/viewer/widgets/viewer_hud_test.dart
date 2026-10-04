import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(ViewerHud, () {
    late List<String?> crumbs;
    late int viewToggled;
    late List<LinkKind> kindsToggled;
    late int searched;
    late int labelsToggled;
    late List<String> nodesSelected;
    late WorldController controller;

    setUp(() {
      crumbs = [];
      viewToggled = 0;
      kindsToggled = [];
      searched = 0;
      labelsToggled = 0;
      nodesSelected = [];
      controller = WorldController();
    });

    tearDown(() => controller.dispose());

    Widget hud(ViewerReady state, {double endInset = 0}) => Scaffold(
      body: ViewerHud(
        state: state,
        controller: controller,
        endInset: endInset,
        onCrumbTap: crumbs.add,
        onToggleViewMode: () => viewToggled++,
        onToggleLinkKind: kindsToggled.add,
        onSearch: () => searched++,
        onToggleLabels: () => labelsToggled++,
        onSelectNode: nodesSelected.add,
      ),
    );

    testWidgets('at the world: only the world crumb and the legend', (
      tester,
    ) async {
      await tester.pumpApp(hud(ViewerReady(map: nestedMap())));

      expect(find.text('World'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      // The legend lists the kinds the map has links of.
      expect(find.text('Calls'), findsOneWidget);
      expect(find.text('Imports'), findsOneWidget);
      expect(find.text('Implements'), findsOneWidget);
      expect(find.text('Mixins'), findsNothing);
      expect(find.byType(ViewModeToggle), findsNothing);
      expect(find.text('11 spheres · 8 links'), findsOneWidget);
    });

    testWidgets('inside a sphere: the path and the view toggle', (
      tester,
    ) async {
      await tester.pumpApp(
        hud(
          ViewerReady(
            map: nestedMap(),
            currentContainerId: 'A.B',
            viewMode: ViewMode.window,
          ),
        ),
      );

      expect(find.text('World'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Window'), findsOneWidget);
    });

    testWidgets('reports crumb taps, the view toggle and legend taps', (
      tester,
    ) async {
      await tester.pumpApp(
        hud(ViewerReady(map: nestedMap(), currentContainerId: 'A.B')),
      );

      await tester.tap(find.widgetWithText(TextButton, 'World'));
      await tester.tap(find.widgetWithText(TextButton, 'A'));
      await tester.tap(find.text('Inside'));
      await tester.tap(find.widgetWithText(FilterChip, 'Imports'));

      expect(crumbs, [null, 'A']);
      expect(viewToggled, 1);
      expect(kindsToggled, [LinkKind.import]);
    });

    testWidgets('shows which link kinds are hidden', (tester) async {
      await tester.pumpApp(
        hud(
          ViewerReady(
            map: nestedMap(),
            visibleLinkKinds: const {LinkKind.call},
          ),
        ),
      );

      final selected = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .map((chip) => chip.selected);
      expect(selected, [true, false, false]);
    });

    testWidgets('has no legend for a map without links', (tester) async {
      await tester.pumpApp(hud(ViewerReady(map: mapWithoutLinks())));

      expect(find.byType(LinkLegend), findsNothing);
      expect(find.text('4 spheres · 0 links'), findsOneWidget);
    });

    testWidgets('fits a phone in French, with large text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        hud(ViewerReady(map: nestedMap(), currentContainerId: 'A.B')),
        locale: const Locale('fr'),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Monde'), findsOneWidget);
    });
  });
}
