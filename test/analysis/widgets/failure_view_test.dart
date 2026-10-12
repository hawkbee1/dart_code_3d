import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/widgets/failure_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(FailureView, () {
    late int retried;
    late int changed;

    setUp(() {
      retried = 0;
      changed = 0;
    });

    Future<void> pump(
      WidgetTester tester,
      BuildFailure failure, {
      bool retryable = false,
      Locale locale = const Locale('en'),
    }) async {
      tester.view
        ..physicalSize = const Size(600, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: FailureView(
              failure: failure,
              onChangeSource: () => changed++,
              onRetry: retryable ? () => retried++ : null,
            ),
          ),
        ),
        locale: locale,
      );
    }

    testWidgets('explains a failure in the words of its kind', (tester) async {
      await pump(
        tester,
        const BuildFailure(
          BuildFailureKind.privateOrMissingRepo,
          'English only',
        ),
      );

      expect(find.text('Repository not found'), findsOneWidget);
      expect(
        find.textContaining('Private repositories are not supported yet'),
        findsOneWidget,
      );
      expect(find.text('English only'), findsNothing);
    });

    testWidgets('offers to try again only when asked to', (tester) async {
      const failure = BuildFailure(BuildFailureKind.network, 'offline');

      await pump(tester, failure, retryable: true);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);

      await pump(tester, failure);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('goes back to the form', (tester) async {
      await pump(
        tester,
        const BuildFailure(BuildFailureKind.invalidArchive, 'bad'),
      );

      await tester.tap(find.text('Change source'));

      expect(changed, 1);
    });

    testWidgets('keeps the technical details folded until asked', (
      tester,
    ) async {
      await pump(
        tester,
        const BuildFailure(
          BuildFailureKind.analysisError,
          'The analysis failed.',
          details: 'StateError: boom\n#0 main (file.dart:1)',
        ),
        retryable: true,
      );
      expect(find.text('Technical details'), findsOneWidget);
      expect(find.textContaining('StateError: boom'), findsNothing);

      await tester.tap(find.text('Technical details'));
      await tester.pumpAndSettle();

      expect(find.textContaining('StateError: boom'), findsOneWidget);
    });

    testWidgets('shows no details box without details', (tester) async {
      await pump(
        tester,
        const BuildFailure(BuildFailureKind.network, 'offline'),
      );

      expect(find.text('Technical details'), findsNothing);
    });

    testWidgets('speaks French', (tester) async {
      await pump(
        tester,
        const BuildFailure(BuildFailureKind.rateLimited, 'later'),
        retryable: true,
        locale: const Locale('fr'),
      );

      expect(find.text('Trop de téléchargements'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Changer de source'), findsOneWidget);
    });

    testWidgets('announces the failure as a heading that appears', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const BuildFailure(BuildFailureKind.network, 'x'));

      expect(
        tester.getSemantics(find.text('No connection')),
        matchesSemantics(
          label: 'No connection',
          isHeader: true,
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('has big enough buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const BuildFailure(BuildFailureKind.network, 'offline'),
        retryable: true,
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
