import 'package:dart_code_3d/home/home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  group(HomePage, () {
    late GoRouter router;

    setUp(() {
      router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);
    });

    testWidgets('meets the tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const HomePage(), router: router);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    for (final (label, location) in [
      ('Settings', '/settings'),
      ('New analysis', '/new-analysis'),
      ('Open file', '/new-analysis'),
      ('3D demo', '/viewer'),
    ]) {
      testWidgets('"$label" goes to $location', (tester) async {
        await tester.pumpApp(const HomePage(), router: router);

        await tester.tap(
          label == 'Settings' ? find.byTooltip(label) : find.text(label),
        );

        verify(() => router.go(location)).called(1);
      });
    }
  });
}
