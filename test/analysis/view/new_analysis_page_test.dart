import 'dart:async';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';
import '../../helpers/settings.dart';

class _MockGoRouter extends Mock implements GoRouter;

class _FakeSource extends Fake implements AnalysisRules;

void main() {
  group(NewAnalysisPage, () {
    late MockCodeMapRepository repository;
    late MockFileDialogs dialogs;
    late GoRouter router;
    late StreamController<BuildEvent> events;
    late CancelToken? token;

    const url = 'https://github.com/TalaoDAO/AltMe';

    setUpAll(() {
      registerFallbackValue(const LocalFolderSource('/x'));
      registerFallbackValue(_FakeSource());
    });

    setUp(() {
      repository = repositoryWith();
      dialogs = MockFileDialogs();
      router = _MockGoRouter();
      events = StreamController<BuildEvent>();
      token = null;
      when(() => router.go(any())).thenReturn(null);
      when(() => router.push<void>(any(), extra: any(named: 'extra')))
          .thenAnswer((_) async {});
      when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
          .thenAnswer((invocation) {
            token = invocation.namedArguments[#cancel] as CancelToken;
            return events.stream;
          });
    });

    // Not awaited: closing a stream nobody listened to never completes.
    tearDown(() => unawaited(events.close()));

    Future<void> pump(
      WidgetTester tester, {
      PlatformCapabilities capabilities = PlatformCapabilities.desktop,
      Locale locale = const Locale('en'),
    }) async {
      tester.view
        ..physicalSize = const Size(900, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const NewAnalysisPage(),
        repository: repository,
        dialogs: dialogs,
        capabilities: capabilities,
        router: router,
        settingsBloc: settingsBlocWith(),
        locale: locale,
      );
    }

    /// Lets a dialog or a route animation finish (the spinner of a running
    /// analysis never stops, so the tree never settles).
    Future<void> animate(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Types [url] and starts the analysis.
    Future<void> start(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Repository URL'),
        url,
      );
      await tester.pump();
      await tester.tap(find.text('Analyze'));
      await tester.pump();
    }

    group('the source choice', () {
      testWidgets('offers git, folders and zip files on a desktop', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('Git repository'), findsOneWidget);
        expect(find.text('Local folder'), findsOneWidget);
        expect(find.text('Zip file'), findsOneWidget);
      });

      testWidgets('offers git and zip files on a phone, no folders', (
        tester,
      ) async {
        await pump(tester, capabilities: PlatformCapabilities.mobile);

        expect(find.text('Git repository'), findsOneWidget);
        expect(find.text('Local folder'), findsNothing);
        expect(find.text('Zip file'), findsOneWidget);
      });

      testWidgets('offers only a zip file in a browser, and says why', (
        tester,
      ) async {
        await pump(tester, capabilities: PlatformCapabilities.web);

        expect(find.text('Git repository'), findsNothing);
        expect(find.text('Local folder'), findsNothing);
        expect(find.text('Choose a zip file…'), findsOneWidget);
        expect(
          find.text('Git repositories are not available in a browser'),
          findsOneWidget,
        );
      });

      testWidgets('opens the settings on top of the form', (tester) async {
        await pump(tester);

        await tester.tap(find.text('Edit rules'));

        verify(() => router.push<void>('/settings')).called(1);
      });
    });

    group('an analysis', () {
      testWidgets('shows its progress, then opens the map in the viewer', (
        tester,
      ) async {
        await pump(tester);
        await start(tester);
        expect(find.text('Analyzing AltMe'), findsOneWidget);
        expect(find.text('Repository URL'), findsNothing);

        events.add(
          const BuildProgress(
            BuildStage.analyzing,
            0.4,
            detail: 'lib/main.dart',
          ),
        );
        await tester.pump();
        expect(find.text('40 %'), findsOneWidget);
        expect(find.text('lib/main.dart'), findsOneWidget);

        events.add(BuildSucceeded(codeMapFileOf(id: '9-z')));
        await tester.pump();
        await tester.pump();

        verify(() => router.go('/viewer?id=9-z')).called(1);
        verify(() => repository.save(any())).called(1);
      });

      testWidgets('is built from what the form holds and the rules', (
        tester,
      ) async {
        await pump(tester);

        await start(tester);

        verify(
          () => repository.build(
            const GitRepositorySource(url),
            AnalysisRules.defaults(),
            cancel: any(named: 'cancel'),
          ),
        ).called(1);
      });
    });

    group('a failure', () {
      testWidgets('is explained, and the form comes back with its content', (
        tester,
      ) async {
        await pump(tester);
        await start(tester);

        events.add(
          const BuildFailed(
            BuildFailure(BuildFailureKind.privateOrMissingRepo, 'nope'),
          ),
        );
        await tester.pump();
        expect(find.text('Repository not found'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);

        await tester.tap(find.text('Change source'));
        await tester.pump();

        expect(find.text('Repository URL'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.widgetWithText(TextField, 'Repository URL'),
              )
              .controller!
              .text,
          url,
        );
      });

      testWidgets('can be tried again when that may help', (tester) async {
        await pump(tester);
        await start(tester);
        events.add(
          const BuildFailed(BuildFailure(BuildFailureKind.network, 'offline')),
        );
        await tester.pump();
        expect(find.text('No connection'), findsOneWidget);

        events = StreamController<BuildEvent>();
        await tester.tap(find.text('Try again'));
        await tester.pump();

        expect(find.text('Analyzing AltMe'), findsOneWidget);
        verify(
          () => repository.build(any(), any(), cancel: any(named: 'cancel')),
        ).called(2);
      });

      testWidgets('shows the details of an analysis bug', (tester) async {
        await pump(tester);
        await start(tester);

        events.add(
          const BuildFailed(
            BuildFailure(
              BuildFailureKind.analysisError,
              'The analysis failed.',
              details: 'StateError: boom',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Technical details'), findsOneWidget);
      });

      testWidgets('says the map could not be stored', (tester) async {
        when(
          () => repository.save(any()),
        ).thenThrow(const BuildFailure(BuildFailureKind.storage, 'disk full'));
        await pump(tester);
        await start(tester);

        events.add(BuildSucceeded(codeMapFileOf()));
        await tester.pump();
        await tester.pump();

        expect(find.text('The map could not be stored'), findsOneWidget);
        verifyNever(() => router.go(any()));
      });
    });

    group('cancelling', () {
      testWidgets('asks first, and keeps going when told to', (tester) async {
        await pump(tester);
        await start(tester);

        await tester.tap(find.text('Cancel'));
        await animate(tester);
        expect(find.text('Cancel the analysis?'), findsOneWidget);
        await tester.tap(find.text('Keep going'));
        await animate(tester);

        expect(find.text('Analyzing AltMe'), findsOneWidget);
        expect(token!.isCancelled, isFalse);
      });

      testWidgets('goes back to the form when confirmed', (tester) async {
        await pump(tester);
        await start(tester);

        await tester.tap(find.text('Cancel'));
        await animate(tester);
        await tester.tap(find.text('Cancel analysis'));
        await animate(tester);

        expect(find.text('Repository URL'), findsOneWidget);
        expect(token!.isCancelled, isTrue);
      });

      testWidgets('is asked for by the back button too', (tester) async {
        await pump(tester);
        await start(tester);

        await tester.binding.handlePopRoute();
        await animate(tester);

        expect(find.text('Cancel the analysis?'), findsOneWidget);
      });
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Nouvelle analyse'), findsOneWidget);
      expect(
        find.text('Choisissez le code Dart à cartographier.'),
        findsOneWidget,
      );
    });
  });
}
