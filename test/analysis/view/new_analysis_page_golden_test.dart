// goldenTest tags every test with TestTag.golden.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:dart_code_3d/analysis/cubit/source_form_cubit.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/helpers.dart';
import '../../helpers/settings.dart';

class _MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc;

const List<SourceKind> _desktopKinds = [
  SourceKind.git,
  SourceKind.folder,
  SourceKind.zip,
];

const _longFile =
    'packages/code_analysis_engine/lib/src/resolve/'
    'declared_type_resolver.dart';

void main() {
  group(NewAnalysisPage, () {
    late SourceFormCubit form;
    late MockFileDialogs dialogs;

    setUp(() => dialogs = MockFileDialogs());

    /// The screen over [state], with a form of [kinds] that [prepare] fills
    /// before the screen is built (the fields read the form when they start).
    Widget screen({
      AnalysisState state = const AnalysisIdle(),
      List<SourceKind> kinds = _desktopKinds,
      bool gitUnavailable = false,
      void Function(SourceFormCubit form)? prepare,
    }) {
      final analysis = _MockAnalysisBloc();
      whenListen(
        analysis,
        const Stream<AnalysisState>.empty(),
        initialState: state,
      );
      form = SourceFormCubit(dialogs: dialogs, kinds: kinds);
      prepare?.call(form);
      return MultiBlocProvider(
        providers: [
          BlocProvider<AnalysisBloc>.value(value: analysis),
          BlocProvider.value(value: form),
        ],
        child: NewAnalysisView(gitUnavailable: gitUnavailable),
      );
    }

    SettingsBloc Function() withRules([AnalysisRules? rules]) =>
        () => settingsBlocWith(
          SettingsState(
            status: SettingsStatus.ready,
            rules: rules ?? AnalysisRules.defaults(),
          ),
        );

    group('the form', () {
      goldenTest(
        'asks for a git repository',
        fileName: 'analysis_form_git',
        locales: const [Locale('en'), Locale('fr')],
        settingsBloc: withRules(),
        builder: screen,
      );

      goldenTest(
        'flags a URL that is not a repository',
        fileName: 'analysis_form_invalid_url',
        devices: const [GoldenDevice.phone, GoldenDevice.desktop],
        settingsBloc: withRules(),
        builder: () => screen(
          prepare: (form) =>
              form.urlChanged('https://example.com/some/project'),
        ),
      );

      goldenTest(
        'is ready, and shows the rules that were changed',
        fileName: 'analysis_form_ready',
        settingsBloc: withRules(
          AnalysisRules.defaults()
              .copyWith(RuleIds.excludeTests, false)
              .copyWith(RuleIds.ambiguousCalls, 'skip')
              .copyWith(RuleIds.generatedPatterns, const ['**/*.mine.dart']),
        ),
        builder: () => screen(
          prepare: (form) => form
            ..urlChanged('https://github.com/bdero/flutter_scene')
            ..refChanged('flutter_scene-0.23.0'),
        ),
      );

      goldenTest(
        'shows the folder that was chosen',
        fileName: 'analysis_form_folder',
        devices: const [GoldenDevice.phone, GoldenDevice.desktop],
        themeModes: const [ThemeMode.light],
        settingsBloc: withRules(),
        builder: screen,
        pump: (tester) async {
          when(dialogs.pickFolder).thenAnswer(
            (_) async => '/home/developer/projects/clients/altme/mobile_app',
          );
          form.kindChanged(SourceKind.folder);
          await form.folderPicked();
          await tester.pump();
        },
      );

      goldenTest(
        'shows the zip file that was chosen',
        fileName: 'analysis_form_zip',
        devices: const [GoldenDevice.phone, GoldenDevice.desktop],
        themeModes: const [ThemeMode.light],
        settingsBloc: withRules(),
        builder: screen,
        pump: (tester) async {
          when(dialogs.pickZip).thenAnswer(
            (_) async =>
                PickedFile(name: 'altme-main.zip', bytes: Uint8List(8)),
          );
          form.kindChanged(SourceKind.zip);
          await form.zipPicked();
          await tester.pump();
        },
      );

      goldenTest(
        'offers a zip file alone in a browser, and says why',
        fileName: 'analysis_form_web',
        locales: const [Locale('en'), Locale('fr')],
        settingsBloc: withRules(),
        builder: () =>
            screen(kinds: const [SourceKind.zip], gitUnavailable: true),
      );

      goldenTest(
        'stays readable with large text',
        fileName: 'analysis_form_git',
        devices: const [GoldenDevice.phone],
        themeModes: const [ThemeMode.light],
        textScale: 2,
        settingsBloc: withRules(),
        builder: screen,
      );
    });

    group('the progress', () {
      for (final (name, state) in [
        (
          'fetching',
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.fetching,
            fraction: 0.12,
          ),
        ),
        (
          'analyzing',
          const AnalysisRunning(
            label: 'flutter_scene',
            stage: BuildStage.analyzing,
            fraction: 0.46,
            detail: _longFile,
          ),
        ),
        (
          'laying_out',
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.layingOut,
            fraction: 0.8,
          ),
        ),
        (
          'saving',
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.encoding,
            fraction: 1,
          ),
        ),
      ]) {
        goldenTest(
          'shows the $name stage',
          fileName: 'analysis_progress_$name',
          locales: name == 'analyzing'
              ? const [Locale('en'), Locale('fr')]
              : const [Locale('en')],
          builder: () => screen(state: state),
          pump: (tester) => tester.pump(const Duration(seconds: 42)),
        );
      }

      goldenTest(
        'stays readable with large text',
        fileName: 'analysis_progress_analyzing',
        devices: const [GoldenDevice.phone],
        themeModes: const [ThemeMode.light],
        textScale: 2,
        builder: () => screen(
          state: const AnalysisRunning(
            label: 'flutter_scene',
            stage: BuildStage.analyzing,
            fraction: 0.46,
            detail: _longFile,
          ),
        ),
      );

      goldenTest(
        'asks before cancelling',
        fileName: 'analysis_cancel_dialog',
        builder: () => screen(
          state: const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.analyzing,
            fraction: 0.3,
          ),
        ),
        pump: (tester) async {
          await tester.tap(find.text('Cancel'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        },
      );
    });

    group('a failure', () {
      // The layout is the same for every kind: the three that differ (a
      // retry, no retry, technical details) are drawn in full, the others on
      // a phone and a desktop in the light theme.
      const full = {
        BuildFailureKind.network,
        BuildFailureKind.privateOrMissingRepo,
        BuildFailureKind.analysisError,
      };
      for (final kind in BuildFailureKind.values.where(
        (k) =>
            k != BuildFailureKind.cancelled &&
            k != BuildFailureKind.invalidFile,
      )) {
        goldenTest(
          'explains ${kind.name}',
          fileName: 'analysis_failure_${kind.name}',
          devices: full.contains(kind)
              ? GoldenDevice.values
              : const [GoldenDevice.phone, GoldenDevice.desktop],
          themeModes: full.contains(kind)
              ? const [ThemeMode.light, ThemeMode.dark]
              : const [ThemeMode.light],
          locales: kind == BuildFailureKind.network
              ? const [Locale('en'), Locale('fr')]
              : const [Locale('en')],
          builder: () => screen(
            state: AnalysisFailed(
              BuildFailure(
                kind,
                'The message of the repository, in English.',
                details: kind == BuildFailureKind.analysisError
                    ? 'StateError: Bad state: no element\n'
                          '#0      Iterable.first (dart:core/iterable.dart:808)\n'
                          '#1      DeclaredTypeResolver.resolve '
                          '(declared_type_resolver.dart:112)'
                    : null,
              ),
            ),
          ),
        );
      }

      goldenTest(
        'shows the technical details of an analysis bug when opened',
        fileName: 'analysis_failure_details',
        devices: const [GoldenDevice.phone, GoldenDevice.desktop],
        themeModes: const [ThemeMode.light],
        builder: () => screen(
          state: const AnalysisFailed(
            BuildFailure(
              BuildFailureKind.analysisError,
              'The analysis failed.',
              details:
                  'StateError: Bad state: no element\n'
                  '#0      Iterable.first (dart:core/iterable.dart:808)\n'
                  '#1      DeclaredTypeResolver.resolve '
                  '(declared_type_resolver.dart:112)',
            ),
          ),
        ),
        pump: (tester) async {
          await tester.tap(find.text('Technical details'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        },
      );
    });
  });
}
