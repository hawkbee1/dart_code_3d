import 'package:dart_code_3d/analysis/widgets/elapsed_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(formatElapsed, () {
    for (final (seconds, text) in [
      (0, '0:00'),
      (7, '0:07'),
      (65, '1:05'),
      (600, '10:00'),
      (3599, '59:59'),
      (3600, '1:00:00'),
      (3725, '1:02:05'),
    ]) {
      test('writes $seconds s as $text', () {
        expect(formatElapsed(seconds), text);
      });
    }
  });

  group(ElapsedClock, () {
    testWidgets('starts at zero and counts the seconds', (tester) async {
      await tester.pumpApp(const ElapsedClock());
      expect(find.text('Elapsed: 0:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Elapsed: 0:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 64));
      expect(find.text('Elapsed: 1:05'), findsOneWidget);
    });

    testWidgets('speaks French', (tester) async {
      await tester.pumpApp(const ElapsedClock(), locale: const Locale('fr'));

      expect(find.text('Écoulé : 0:00'), findsOneWidget);
    });

    testWidgets('stops counting when it leaves', (tester) async {
      await tester.pumpApp(const ElapsedClock());

      await tester.pumpWidget(const SizedBox());

      // A running timer would fail the test at its end.
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
