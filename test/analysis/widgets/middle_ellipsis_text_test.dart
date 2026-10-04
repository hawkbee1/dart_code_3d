import 'package:dart_code_3d/analysis/widgets/middle_ellipsis_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ellipsizeMiddle, () {
    bool Function(String) fitsIn(int width) =>
        (candidate) => candidate.length <= width;

    test('keeps a text that fits', () {
      expect(ellipsizeMiddle('lib/main.dart', fitsIn(20)), 'lib/main.dart');
    });

    test('cuts in the middle and keeps both ends, the file name first', () {
      final result = ellipsizeMiddle(
        'lib/src/very/deep/folder/main.dart',
        fitsIn(15),
      );

      expect(result, 'lib/s…main.dart');
      expect(result.length, lessThanOrEqualTo(15));
      expect(result, startsWith('lib/'));
      expect(result, endsWith('.dart'));
    });

    test('keeps more of the end than of the start', () {
      expect(ellipsizeMiddle('abcdefghij', fitsIn(6)), 'ab…hij');
      expect(ellipsizeMiddle('abcdefghij', fitsIn(4)), 'a…ij');
    });

    test('keeps only the ellipsis when nothing else fits', () {
      expect(ellipsizeMiddle('abcdefghij', fitsIn(1)), '…');
    });

    test('is the ellipsis even when not even that fits', () {
      expect(ellipsizeMiddle('abcdefghij', (_) => false), '…');
    });
  });

  group(MiddleEllipsisText, () {
    Future<void> pump(WidgetTester tester, String text, double width) =>
        tester.pumpApp(
          Scaffold(
            body: Center(
              child: SizedBox(width: width, child: MiddleEllipsisText(text)),
            ),
          ),
        );

    testWidgets('shows a short text as it is', (tester) async {
      await pump(tester, 'main.dart', 300);

      expect(find.text('main.dart'), findsOneWidget);
    });

    testWidgets('cuts a long path in the middle to fit', (tester) async {
      const path =
          'packages/code_analysis_engine/lib/src/resolve/link_builder.dart';

      await pump(tester, path, 200);

      final shown = tester.widget<Text>(find.byType(Text)).data!;
      expect(shown, contains('…'));
      expect(shown, startsWith('packages'));
      expect(shown, endsWith('builder.dart'));
      expect(tester.getSize(find.byType(Text)).width, lessThanOrEqualTo(200));
    });

    testWidgets('keeps the whole text for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      const path =
          'packages/code_analysis_engine/lib/src/resolve/link_builder.dart';

      await pump(tester, path, 120);

      expect(find.bySemanticsLabel(path), findsOneWidget);
      handle.dispose();
    });

    testWidgets('cuts again when the width shrinks', (tester) async {
      const path =
          'packages/code_analysis_engine/lib/src/resolve/link_builder.dart';
      await pump(tester, path, 300);
      final wide = tester.widget<Text>(find.byType(Text)).data!;

      await pump(tester, path, 150);

      expect(
        tester.widget<Text>(find.byType(Text)).data!.length,
        lessThan(wide.length),
      );
    });
  });
}
