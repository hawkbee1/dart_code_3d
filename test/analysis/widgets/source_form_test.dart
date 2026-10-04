import 'package:bloc_test/bloc_test.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:dart_code_3d/analysis/cubit/source_form_cubit.dart';
import 'package:dart_code_3d/analysis/widgets/source_form.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/helpers.dart';
import '../../helpers/settings.dart';

class _MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc;

void main() {
  group(SourceForm, () {
    late MockFileDialogs dialogs;
    late _MockAnalysisBloc analysis;
    late int edited;

    setUpAll(() => registerFallbackValue(const AnalysisCancelled()));

    setUp(() {
      dialogs = MockFileDialogs();
      analysis = _MockAnalysisBloc();
      when(() => analysis.state).thenReturn(const AnalysisIdle());
      edited = 0;
    });

    SourceFormCubit form({
      List<SourceKind> kinds = const [
        SourceKind.git,
        SourceKind.folder,
        SourceKind.zip,
      ],
    }) => SourceFormCubit(dialogs: dialogs, kinds: kinds);

    Future<void> pump(
      WidgetTester tester, {
      SourceFormCubit? cubit,
      AnalysisRules? rules,
      bool gitUnavailable = false,
      Locale locale = const Locale('en'),
      double width = 900,
    }) async {
      tester.view
        ..physicalSize = Size(width, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final created = cubit ?? form();
      addTearDown(created.close);
      await tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<AnalysisBloc>.value(value: analysis),
            BlocProvider.value(value: created),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              child: SourceForm(
                gitUnavailable: gitUnavailable,
                onEditRules: () => edited++,
              ),
            ),
          ),
        ),
        settingsBloc: settingsBlocWith(
          SettingsState(
            status: SettingsStatus.ready,
            rules: rules ?? AnalysisRules.defaults(),
          ),
        ),
        locale: locale,
      );
    }

    FilledButton analyzeButton(WidgetTester tester) =>
        tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Analyze'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
        );

    group('with every kind of source', () {
      testWidgets('offers the three kinds, on git first', (tester) async {
        await pump(tester);

        expect(find.text('Git repository'), findsOneWidget);
        expect(find.text('Local folder'), findsOneWidget);
        expect(find.text('Zip file'), findsOneWidget);
        expect(find.text('Repository URL'), findsOneWidget);
      });

      testWidgets('shortens the labels on a narrow screen', (tester) async {
        await pump(tester, width: 390);

        expect(find.text('Git'), findsOneWidget);
        expect(find.text('Folder'), findsOneWidget);
        expect(find.text('Zip'), findsOneWidget);
        expect(find.text('Git repository'), findsNothing);
        expect(find.byIcon(Icons.cloud_download_outlined), findsNothing);
      });

      testWidgets('writes the labels in full, with icons, when wide', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('Git repository'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
      });

      testWidgets('switches the fields with the kind', (tester) async {
        await pump(tester);

        await tester.tap(find.text('Local folder'));
        await tester.pump();
        expect(find.text('Repository URL'), findsNothing);
        expect(find.text('Choose a folder…'), findsOneWidget);
        expect(find.text('No folder chosen'), findsOneWidget);

        await tester.tap(find.text('Zip file'));
        await tester.pump();
        expect(find.text('Choose a zip file…'), findsOneWidget);
        expect(find.text('No file chosen'), findsOneWidget);
      });

      testWidgets('does not say that git is unavailable', (tester) async {
        await pump(tester);

        expect(find.textContaining('not available in a browser'), findsNothing);
      });
    });

    group('git repository', () {
      testWidgets('cannot analyze before a URL is typed', (tester) async {
        await pump(tester);

        expect(analyzeButton(tester).onPressed, isNull);
        expect(
          find.text('Not a GitHub or GitLab repository URL'),
          findsNothing,
        );
      });

      testWidgets('flags a URL that is not a repository, and fixes it', (
        tester,
      ) async {
        await pump(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Repository URL'),
          'https://example.com/o/r',
        );
        await tester.pump();
        expect(
          find.text('Not a GitHub or GitLab repository URL'),
          findsOneWidget,
        );
        expect(analyzeButton(tester).onPressed, isNull);

        await tester.enterText(
          find.widgetWithText(TextField, 'Repository URL'),
          'https://github.com/TalaoDAO/AltMe',
        );
        await tester.pump();
        expect(
          find.text('Not a GitHub or GitLab repository URL'),
          findsNothing,
        );
        expect(analyzeButton(tester).onPressed, isNotNull);
      });

      testWidgets(
        'starts the analysis with the URL, the branch and the rules',
        (tester) async {
          final rules = AnalysisRules.defaults().copyWith(
            RuleIds.excludeTests,
            false,
          );
          await pump(tester, rules: rules);
          await tester.enterText(
            find.widgetWithText(TextField, 'Repository URL'),
            'https://github.com/bdero/flutter_scene',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Branch or tag (optional)'),
            'flutter_scene-0.23.0',
          );
          await tester.pump();

          await tester.tap(find.text('Analyze'));

          verify(
            () => analysis.add(
              AnalysisStarted(
                const GitRepositorySource(
                  'https://github.com/bdero/flutter_scene',
                  ref: 'flutter_scene-0.23.0',
                ),
                rules,
              ),
            ),
          ).called(1);
        },
      );

      testWidgets('starts the analysis from the keyboard', (tester) async {
        await pump(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Repository URL'),
          'github.com/o/r',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Branch or tag (optional)'),
          'dev',
        );

        await tester.testTextInput.receiveAction(TextInputAction.done);

        verify(() => analysis.add(any(that: isA<AnalysisStarted>()))).called(1);
      });

      testWidgets('does not start from the keyboard with an invalid URL', (
        tester,
      ) async {
        await pump(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Branch or tag (optional)'),
          'dev',
        );

        await tester.testTextInput.receiveAction(TextInputAction.done);

        verifyNever(() => analysis.add(any()));
      });

      testWidgets('comes back filled in', (tester) async {
        final cubit = form()
          ..urlChanged('https://github.com/TalaoDAO/AltMe')
          ..refChanged('main');

        await pump(tester, cubit: cubit);

        String typed(String label) => tester
            .widget<TextField>(find.widgetWithText(TextField, label))
            .controller!
            .text;
        expect(typed('Repository URL'), 'https://github.com/TalaoDAO/AltMe');
        expect(typed('Branch or tag (optional)'), 'main');
        expect(analyzeButton(tester).onPressed, isNotNull);
      });

      testWidgets('says that only public repositories work', (tester) async {
        await pump(tester);

        expect(find.text('Public repositories only.'), findsOneWidget);
      });
    });

    group('local folder', () {
      testWidgets('shows the folder that was picked and analyzes it', (
        tester,
      ) async {
        when(dialogs.pickFolder).thenAnswer((_) async => '/home/dev/AltMe');
        await pump(tester);
        await tester.tap(find.text('Local folder'));
        await tester.pump();

        await tester.tap(find.text('Choose a folder…'));
        await tester.pump();

        expect(find.text('/home/dev/AltMe'), findsOneWidget);
        expect(find.text('Change folder…'), findsOneWidget);
        await tester.tap(find.text('Analyze'));
        verify(
          () => analysis.add(
            AnalysisStarted(
              const LocalFolderSource('/home/dev/AltMe'),
              AnalysisRules.defaults(),
            ),
          ),
        ).called(1);
      });

      testWidgets('cannot analyze before a folder is picked', (tester) async {
        await pump(tester);
        await tester.tap(find.text('Local folder'));
        await tester.pump();

        expect(analyzeButton(tester).onPressed, isNull);
      });
    });

    group('zip file', () {
      testWidgets('shows the file that was picked and analyzes it', (
        tester,
      ) async {
        final zip = PickedFile(name: 'app.zip', bytes: Uint8List(4));
        when(dialogs.pickZip).thenAnswer((_) async => zip);
        await pump(tester);
        await tester.tap(find.text('Zip file'));
        await tester.pump();

        await tester.tap(find.text('Choose a zip file…'));
        await tester.pump();

        expect(find.text('app.zip'), findsOneWidget);
        expect(find.text('Change file…'), findsOneWidget);
        await tester.tap(find.text('Analyze'));
        verify(
          () => analysis.add(
            AnalysisStarted(
              ZipBytesSource(fileName: 'app.zip', bytes: zip.bytes),
              AnalysisRules.defaults(),
            ),
          ),
        ).called(1);
      });
    });

    group('where git is not available', () {
      testWidgets('says why and offers the zip alone', (tester) async {
        await pump(
          tester,
          cubit: form(kinds: const [SourceKind.zip]),
          gitUnavailable: true,
        );

        expect(
          find.text('Git repositories are not available in a browser'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Download the repository as a zip'),
          findsOneWidget,
        );
        expect(find.byType(SegmentedButton<SourceKind>), findsNothing);
        expect(find.text('Choose a zip file…'), findsOneWidget);
      });
    });

    group('rules', () {
      testWidgets('shows a summary and asks to edit', (tester) async {
        await pump(tester);

        expect(find.text('Default rules'), findsOneWidget);
        await tester.tap(find.text('Edit rules'));

        expect(edited, 1);
      });

      testWidgets('summarizes the rules from the settings', (tester) async {
        await pump(
          tester,
          rules: AnalysisRules.defaults().copyWith(RuleIds.excludeTests, false),
        );

        expect(find.text('1 rule differs from the defaults'), findsOneWidget);
      });
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Dépôt git'), findsOneWidget);
      expect(find.text('Analyser'), findsOneWidget);
      expect(find.text('Dépôts publics uniquement.'), findsOneWidget);
    });
  });
}
