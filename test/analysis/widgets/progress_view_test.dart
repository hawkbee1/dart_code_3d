import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:dart_code_3d/analysis/widgets/progress_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ProgressView, () {
    late int cancelled;

    setUp(() => cancelled = 0);

    AnalysisRunning running(
      BuildStage stage, {
      double fraction = 0.3,
      String? detail,
    }) => AnalysisRunning(
      label: 'AltMe',
      stage: stage,
      fraction: fraction,
      detail: detail,
    );

    Future<void> pump(
      WidgetTester tester,
      AnalysisRunning state, {
      bool disableAnimations = false,
      Locale locale = const Locale('en'),
    }) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: ProgressView(state: state, onCancel: () => cancelled++),
        ),
      ),
      disableAnimations: disableAnimations,
      locale: locale,
    );

    LinearProgressIndicator bar(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

    testWidgets('names what is analyzed and lists the four stages', (
      tester,
    ) async {
      await pump(tester, running(BuildStage.fetching, fraction: 0.1));

      expect(find.text('Analyzing AltMe'), findsOneWidget);
      expect(find.text('Getting the code'), findsOneWidget);
      expect(find.text('Analyzing the code'), findsOneWidget);
      expect(find.text('Laying out the spheres'), findsOneWidget);
      expect(find.text('Saving the map'), findsOneWidget);
      expect(find.text('10 %'), findsOneWidget);
    });

    testWidgets('marks the finished stages, the current one and the rest', (
      tester,
    ) async {
      await pump(tester, running(BuildStage.analyzing));

      // Fetching is done; analyzing spins; two stages wait.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });

    testWidgets('marks every stage done but the last while saving', (
      tester,
    ) async {
      await pump(tester, running(BuildStage.encoding, fraction: 1));

      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a determinate bar while fetching and analyzing', (
      tester,
    ) async {
      await pump(tester, running(BuildStage.analyzing, fraction: 0.4));

      expect(bar(tester).value, 0.4);
    });

    testWidgets('keeps moving while the layout cannot report progress', (
      tester,
    ) async {
      await pump(tester, running(BuildStage.layingOut, fraction: 0.8));

      expect(bar(tester).value, isNull);
      expect(
        find.text('Big projects take a few seconds to place.'),
        findsOneWidget,
      );
    });

    testWidgets('keeps moving while saving too', (tester) async {
      await pump(tester, running(BuildStage.encoding, fraction: 1));

      expect(bar(tester).value, isNull);
    });

    group('with reduced motion', () {
      testWidgets('shows the fraction instead of an endless bar', (
        tester,
      ) async {
        await pump(
          tester,
          running(BuildStage.layingOut, fraction: 0.8),
          disableAnimations: true,
        );

        expect(bar(tester).value, 0.8);
      });

      testWidgets('shows the current stage with a still icon', (tester) async {
        await pump(
          tester,
          running(BuildStage.analyzing),
          disableAnimations: true,
        );

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.pending), findsOneWidget);
      });
    });

    testWidgets('shows the file being read, cut in the middle if long', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const file =
          'packages/code_analysis_engine/lib/src/resolve/declared_type_resolver.dart';

      await pump(tester, running(BuildStage.analyzing, detail: file));

      expect(find.bySemanticsLabel(file), findsOneWidget);
      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .firstWhere((t) => t != null && t.contains('…'))!;
      expect(shown, startsWith('packages'));
      expect(shown, endsWith('resolver.dart'));
    });

    testWidgets('shows no file when none is being read', (tester) async {
      await pump(tester, running(BuildStage.fetching));

      expect(find.textContaining('.dart'), findsNothing);
    });

    testWidgets('counts the elapsed time', (tester) async {
      await pump(tester, running(BuildStage.analyzing));

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Elapsed: 0:03'), findsOneWidget);
    });

    testWidgets('cancels', (tester) async {
      await pump(tester, running(BuildStage.analyzing));

      await tester.tap(find.text('Cancel'));

      expect(cancelled, 1);
    });

    testWidgets('names the stage and the percentage for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pump(tester, running(BuildStage.analyzing, fraction: 0.4));

      expect(
        tester.getSemantics(find.byType(LinearProgressIndicator)),
        matchesSemantics(label: 'Analyzing the code', value: '40%'),
      );
      handle.dispose();
    });

    testWidgets('announces the stage that is running, not the others', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, running(BuildStage.analyzing));

      expect(
        tester.getSemantics(find.text('Analyzing the code')),
        matchesSemantics(label: 'Analyzing the code', isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text('Getting the code')),
        matchesSemantics(label: 'Getting the code'),
      );
      expect(
        tester.getSemantics(find.text('Analyzing AltMe')),
        matchesSemantics(label: 'Analyzing AltMe', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('has big enough buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, running(BuildStage.analyzing));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('speaks French', (tester) async {
      await pump(
        tester,
        running(BuildStage.layingOut, fraction: 0.8),
        locale: const Locale('fr'),
      );

      expect(find.text('Analyse de AltMe'), findsOneWidget);
      expect(find.text('Placement des sphères'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });
  });
}
