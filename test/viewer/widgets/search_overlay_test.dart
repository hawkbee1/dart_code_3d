import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(SearchOverlay, () {
    late CodeMap map;
    late List<String> picked;
    late int closed;

    setUp(() {
      map = sampleMap();
      picked = [];
      closed = 0;
    });

    Future<void> pump(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) => tester.pumpApp(
      Scaffold(
        body: SearchOverlay(
          map: map,
          onSelect: picked.add,
          onClose: () => closed++,
        ),
      ),
      locale: locale,
    );

    Future<void> type(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
    }

    String idOf(String name) =>
        map.graph.nodes.values.firstWhere((n) => n.name == name).id;

    testWidgets('invites to type, with the keyboard ready', (tester) async {
      await pump(tester);

      expect(find.text('Type to search the whole map.'), findsOneWidget);
      expect(find.text('Search classes, methods, packages…'), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isTrue);
    });

    testWidgets('takes the focus even when something else has it', (
      tester,
    ) async {
      // The 3D area holds the focus when the search opens.
      await tester.pumpApp(
        const Scaffold(
          body: Stack(
            children: [
              Focus(
                debugLabel: 'world',
                autofocus: true,
                child: SizedBox.expand(),
              ),
            ],
          ),
        ),
      );
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'world');

      await tester.pumpApp(
        Scaffold(
          body: Stack(
            children: [
              const Focus(
                debugLabel: 'world',
                autofocus: true,
                child: SizedBox.expand(),
              ),
              SearchOverlay(map: map, onSelect: picked.add, onClose: () {}),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(FocusManager.instance.primaryFocus?.debugLabel, 'search');
    });

    testWidgets('lists what matches, with the kind and the file', (
      tester,
    ) async {
      await pump(tester);

      await type(tester, 'weathercache');

      // The best match first; its subclass matches too.
      final first = tester.widgetList<ListTile>(find.byType(ListTile)).first;
      expect((first.title! as Text).data, 'WeatherCache');
      expect(
        find.text('Class · lib/weather/data/weather_cache.dart'),
        findsWidgets,
      );
      expect(find.text('Type to search the whole map.'), findsNothing);
    });

    testWidgets('shows a result without a file by its kind alone', (
      tester,
    ) async {
      await pump(tester);

      await type(tester, 'http');

      // Just the kind: a package has no file.
      expect(find.text('External package'), findsOneWidget);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pump(tester);

      await type(tester, 'zzzqq');

      expect(find.text('No match for “zzzqq”'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('picks the result that is tapped', (tester) async {
      await pump(tester);
      await type(tester, 'weathercache');

      await tester.tap(find.text('WeatherCache'));

      expect(picked, [idOf('WeatherCache')]);
    });

    testWidgets('Enter picks the first result', (tester) async {
      await pump(tester);
      await type(tester, 'weathercache');

      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(picked, [idOf('WeatherCache')]);
    });

    testWidgets('Enter without results picks nothing', (tester) async {
      await pump(tester);
      await type(tester, 'zzzqq');

      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(picked, isEmpty);
    });

    testWidgets('the arrow keys move through the results', (tester) async {
      await pump(tester);
      await type(tester, 'weather');
      List<bool> selected() => [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          tile.selected,
      ];
      expect(selected().first, isTrue);
      expect(selected().where((s) => s), hasLength(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(selected()[1], isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(selected().first, isTrue);
    });

    testWidgets('up from the first result wraps to the last', (tester) async {
      await pump(tester);
      await type(tester, 'weather');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(picked.single, SearchIndex.of(map).search('weather').last.id);
    });

    testWidgets('down from the last result wraps to the first', (tester) async {
      await pump(tester);
      await type(tester, 'weather');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(picked.single, SearchIndex.of(map).search('weather').first.id);
    });

    testWidgets('Enter picks the result the arrows chose', (tester) async {
      await pump(tester);
      await type(tester, 'weather');
      final titles = [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          (tile.title! as Text).data!,
      ];

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(map.graph.nodes[picked.single]!.name, titles[1]);
    });

    testWidgets('typing again starts again from the first result', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'weather');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

      await type(tester, 'weathe');

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      expect(tiles.first.selected, isTrue);
    });

    testWidgets('the arrow keys do nothing without results', (tester) async {
      await pump(tester);
      await type(tester, 'zzzqq');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Esc closes it', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(closed, 1);
    });

    testWidgets('other keys are left to the text field', (tester) async {
      await pump(tester);

      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

      expect(handled, isFalse);
      expect(closed, 0);
    });

    testWidgets('the close button closes it', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Close search'));

      expect(closed, 1);
    });

    testWidgets('names each result for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await type(tester, 'weathercache');

      expect(find.bySemanticsLabel('WeatherCache, Class'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, locale: const Locale('fr'));
      expect(
        find.text('Tapez pour chercher dans toute la carte.'),
        findsOneWidget,
      );

      await type(tester, 'zzzqq');

      expect(find.text('Aucun résultat pour « zzzqq »'), findsOneWidget);
    });

    testWidgets('limits the list to the best matches', (tester) async {
      await pump(tester);

      await type(tester, 'e');

      expect(
        tester.widgetList<ListTile>(find.byType(ListTile)).length,
        lessThanOrEqualTo(30),
      );
    });
  });
}
