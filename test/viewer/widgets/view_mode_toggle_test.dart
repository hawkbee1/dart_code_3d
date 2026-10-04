import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ViewModeToggle, () {
    late int toggled;

    setUp(() => toggled = 0);

    Future<void> pump(
      WidgetTester tester,
      ViewMode mode, {
      Locale locale = const Locale('en'),
    }) => tester.pumpApp(
      ViewModeToggle(mode: mode, onToggle: () => toggled++),
      locale: locale,
    );

    testWidgets('names the current mode', (tester) async {
      await pump(tester, ViewMode.interior);
      expect(find.text('Inside'), findsOneWidget);
      expect(find.byIcon(Icons.blur_circular), findsOneWidget);

      await pump(tester, ViewMode.window);
      expect(find.text('Window'), findsOneWidget);
      expect(find.byIcon(Icons.window_outlined), findsOneWidget);
    });

    testWidgets('switches to the other mode when tapped', (tester) async {
      await pump(tester, ViewMode.interior);

      await tester.tap(find.byType(TextButton));

      expect(toggled, 1);
    });

    testWidgets('mentions the V key in its tooltip', (tester) async {
      await pump(tester, ViewMode.interior);

      expect(
        find.byTooltip('Switch between inside and window view (V)'),
        findsOneWidget,
      );
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, ViewMode.window, locale: const Locale('fr'));

      expect(find.text('Fenêtre'), findsOneWidget);
    });
  });
}
