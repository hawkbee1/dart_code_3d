import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(InfoPanel, () {
    late CodeMap nested;
    late CodeMap sample;
    late List<String> calls;

    setUp(() {
      nested = nestedMap();
      sample = sampleMap();
      calls = [];
    });

    NodeDetails sampleDetails(String name) => NodeDetails.of(
      sample,
      sample.graph.nodes.values.firstWhere((n) => n.name == name).id,
    );

    Widget panel(
      NodeDetails details, {
      bool focusOn = false,
      bool enterable = true,
      bool bottomSheet = false,
      double height = 800,
    }) => Scaffold(
      body: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          width: 360,
          height: height,
          child: InfoPanel(
            details: details,
            focusOn: focusOn,
            bottomSheet: bottomSheet,
            onFlyTo: () => calls.add('fly'),
            onEnter: enterable ? () => calls.add('enter') : null,
            onToggleFocus: () => calls.add('focus'),
            onCopyPath: () => calls.add('copy'),
            onClose: () => calls.add('close'),
          ),
        ),
      ),
    );

    testWidgets('describes a class: what it holds and how it is linked', (
      tester,
    ) async {
      await tester.pumpApp(panel(NodeDetails.of(nested, 'A')));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('0 lines of code'), findsOneWidget);
      expect(find.text('1 member · 1 nested type'), findsOneWidget);
      expect(find.text('Calls: 2 out · 2 in'), findsOneWidget);
      expect(find.text('Implements: 1 out · 0 in'), findsOneWidget);
      expect(find.text('Imports: 0 out · 1 in'), findsOneWidget);
    });

    testWidgets('tells how far to trust the links', (tester) async {
      await tester.pumpApp(panel(NodeDetails.of(nested, 'A')));

      // Calls: out 1 exact + 1 ambiguous, in 2 exact.
      expect(find.text('exact 3'), findsOneWidget);
      expect(find.text('ambiguous 1'), findsOneWidget);
      expect(
        find.text(
          'Exact links follow the declared type. '
          'By name and ambiguous ones are guesses.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has no hint when every link is exact', (tester) async {
      await tester.pumpApp(panel(NodeDetails.of(nested, 'G.D.p')));

      expect(find.text('exact 1'), findsOneWidget);
      expect(find.textContaining('guesses'), findsNothing);
    });

    testWidgets('says when there is no link', (tester) async {
      await tester.pumpApp(panel(NodeDetails.of(mapWithoutLinks(), 'A')));

      expect(find.text('No links'), findsOneWidget);
      // Nothing to focus on.
      expect(find.text('Show only its links'), findsNothing);
    });

    testWidgets('gives the location and the qualified name', (tester) async {
      await tester.pumpApp(panel(sampleDetails('locationSearch')));

      expect(find.text('Qualified name'), findsOneWidget);
      expect(find.text('WeatherApiClient.locationSearch'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(
        find.textContaining('lib/weather/data/weather_api_client.dart:'),
        findsOneWidget,
      );
      expect(find.text('Method'), findsOneWidget);
    });

    testWidgets('has neither for a node without a location', (tester) async {
      await tester.pumpApp(panel(NodeDetails.of(nested, 'main')));

      expect(find.text('Function'), findsOneWidget);
      expect(find.text('Location'), findsNothing);
      expect(find.text('Qualified name'), findsNothing);
    });

    testWidgets('names the package of a ghost parent', (tester) async {
      await tester.pumpApp(panel(sampleDetails('Cubit')));

      expect(find.text('Superclass from outside the project'), findsOneWidget);
      expect(find.text('Package: bloc'), findsOneWidget);
      expect(find.text('3 nested types'), findsOneWidget);
      expect(find.textContaining('lines of code'), findsNothing);
      expect(find.text('Enter'), findsOneWidget);
    });

    testWidgets('admits when a ghost parent has no known package', (
      tester,
    ) async {
      await tester.pumpApp(
        panel(
          const NodeDetails(
            id: 'g',
            name: 'Base',
            qualifiedName: 'Base',
            kind: CodeNodeKind.ghostParent,
            loc: 0,
            members: 0,
            nested: 2,
            links: [],
          ),
        ),
      );

      expect(find.text('Package: unknown'), findsOneWidget);
    });

    testWidgets('says the model of an external package is not there yet', (
      tester,
    ) async {
      await tester.pumpApp(panel(sampleDetails('http'), enterable: false));

      expect(find.text('External package'), findsOneWidget);
      expect(find.text('Package: http'), findsOneWidget);
      expect(find.text('Package model not available yet'), findsOneWidget);
      expect(find.text('Enter'), findsNothing);
      expect(find.textContaining('lines of code'), findsNothing);
    });

    testWidgets('admits when an external package has no name', (tester) async {
      await tester.pumpApp(panel(NodeDetails.of(nested, 'pkg')));

      expect(find.text('Package: unknown'), findsOneWidget);
      expect(find.text('Package model not available yet'), findsOneWidget);
    });

    group('actions', () {
      testWidgets('fly to, enter, focus and copy', (tester) async {
        await tester.pumpApp(panel(NodeDetails.of(nested, 'A')));

        await tester.tap(find.text('Fly to'));
        await tester.tap(find.text('Enter'));
        await tester.tap(find.text('Show only its links'));
        await tester.tap(find.text('Copy path'));

        expect(calls, ['fly', 'enter', 'focus', 'copy']);
      });

      testWidgets('close', (tester) async {
        await tester.pumpApp(panel(NodeDetails.of(nested, 'A')));

        await tester.tap(find.byTooltip('Close'));

        expect(calls, ['close']);
      });

      testWidgets('no Enter without a way in', (tester) async {
        await tester.pumpApp(
          panel(NodeDetails.of(nested, 'A.m'), enterable: false),
        );

        expect(find.text('Enter'), findsNothing);
        expect(find.text('Fly to'), findsOneWidget);
      });

      testWidgets('focus becomes show all while it is on', (tester) async {
        await tester.pumpApp(panel(NodeDetails.of(nested, 'A'), focusOn: true));

        expect(find.text('Show only its links'), findsNothing);
        await tester.tap(find.text('Show all links'));

        expect(calls, ['focus']);
      });

      testWidgets('focus stays available while on, even without links', (
        tester,
      ) async {
        await tester.pumpApp(
          panel(NodeDetails.of(mapWithoutLinks(), 'A'), focusOn: true),
        );

        expect(find.text('Show all links'), findsOneWidget);
      });
    });

    group('shape', () {
      Material materialOf(WidgetTester tester) => tester.widget<Material>(
        find
            .descendant(
              of: find.byType(InfoPanel),
              matching: find.byType(Material),
            )
            .first,
      );

      testWidgets('is square as a side sheet', (tester) async {
        await tester.pumpApp(panel(NodeDetails.of(nested, 'A')));

        final shape = materialOf(tester).shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.zero);
      });

      testWidgets('has a rounded top as a bottom sheet', (tester) async {
        await tester.pumpApp(
          panel(NodeDetails.of(nested, 'A'), bottomSheet: true),
        );

        final shape = materialOf(tester).shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, isNot(BorderRadius.zero));
        final radius = shape.borderRadius.resolve(TextDirection.ltr);
        expect(radius.topLeft.x, greaterThan(0));
        expect(radius.bottomLeft, Radius.zero);
      });
    });

    testWidgets('scrolls when it is short', (tester) async {
      await tester.pumpApp(panel(NodeDetails.of(nested, 'A'), height: 320));

      expect(tester.takeException(), isNull);
      expect(find.text('Fly to'), findsOneWidget);
    });

    testWidgets('is named for screen readers, and its buttons are big', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(panel(NodeDetails.of(nested, 'A')));

      expect(find.bySemanticsLabel('Details of A'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('speaks French', (tester) async {
      await tester.pumpApp(
        panel(NodeDetails.of(nested, 'A')),
        locale: const Locale('fr'),
      );

      expect(find.text('Classe'), findsOneWidget);
      expect(find.text('Y aller'), findsOneWidget);
      expect(find.text('Appels : 2 sortants · 2 entrants'), findsOneWidget);
      expect(find.text('exact 3'), findsOneWidget);
      expect(find.text('ambigu 1'), findsOneWidget);
    });
  });
}
