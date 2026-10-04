import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(Breadcrumb, () {
    late List<String?> tapped;

    setUp(() => tapped = []);

    Breadcrumb breadcrumb(List<Crumb> path) =>
        Breadcrumb(path: path, onCrumbTap: tapped.add);

    const nested = <Crumb>[
      (id: null, name: 'World'),
      (id: 'A', name: 'UserRepository'),
      (id: 'A.B', name: 'CachedUserRepository'),
    ];

    testWidgets('shows every level, the last one as plain text', (
      tester,
    ) async {
      await tester.pumpApp(breadcrumb(nested));

      expect(find.text('World'), findsOneWidget);
      expect(find.text('UserRepository'), findsOneWidget);
      expect(find.text('CachedUserRepository'), findsOneWidget);
      // Two separators between three levels.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      // Only the levels above the current one are buttons.
      expect(find.byType(TextButton), findsNWidgets(2));
      expect(
        find.ancestor(
          of: find.text('CachedUserRepository'),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
    });

    testWidgets('flies to the level that is tapped', (tester) async {
      await tester.pumpApp(breadcrumb(nested));

      await tester.tap(find.text('UserRepository'));
      await tester.tap(find.text('World'));

      expect(tapped, ['A', null]);
    });

    testWidgets('has nothing to tap at the world', (tester) async {
      await tester.pumpApp(breadcrumb(const [(id: null, name: 'World')]));

      expect(find.text('World'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('cuts long names with an ellipsis', (tester) async {
      await tester.pumpApp(
        breadcrumb(const [
          (id: null, name: 'World'),
          (
            id: 'A',
            name: 'AVeryLongClassNameThatWouldNotFitInTheBreadcrumbAtAll',
          ),
          (id: 'A.B', name: 'AnotherExtremelyLongNameForANestedSubclassHere'),
        ]),
      );

      final texts = tester.widgetList<Text>(
        find.byWidgetPredicate((w) => w is Text && (w.data?.length ?? 0) > 30),
      );
      expect(texts, hasLength(2));
      for (final text in texts) {
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
      }
      for (final element in find.byType(Text).evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).width,
          lessThanOrEqualTo(Breadcrumb.maxCrumbWidth),
        );
      }
    });

    testWidgets('wraps a path wider than the screen', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        breadcrumb([
          (id: null, name: 'World'),
          for (var i = 0; i < 6; i++) (id: 'n$i', name: 'Level$i'),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Level5'), findsOneWidget);
    });

    testWidgets('names its buttons and itself for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(breadcrumb(nested));

      expect(find.bySemanticsLabel('Where you are'), findsOneWidget);
      expect(find.bySemanticsLabel('Fly to UserRepository'), findsOneWidget);
      expect(find.bySemanticsLabel('Fly to World'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('speaks French', (tester) async {
      await tester.pumpApp(breadcrumb(nested), locale: const Locale('fr'));

      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel('Aller à UserRepository'), findsOneWidget);
      handle.dispose();
    });
  });
}
