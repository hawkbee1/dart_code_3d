import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/bloc/analysis_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/code_maps.dart';

class _MockCodeMapRepository extends Mock implements CodeMapRepository;

class _FakeRules extends Fake implements AnalysisRules;

class _FakeFile extends Fake implements CodeMapFile;

void main() {
  group(AnalysisBloc, () {
    late CodeMapRepository repository;
    late CodeMapFile file;
    late AnalysisRules rules;

    const source = GitRepositorySource('https://github.com/TalaoDAO/AltMe');

    setUpAll(() {
      registerFallbackValue(const LocalFolderSource('/x'));
      registerFallbackValue(_FakeRules());
      registerFallbackValue(_FakeFile());
    });

    setUp(() {
      repository = _MockCodeMapRepository();
      file = codeMapFileOf(id: '9-z');
      rules = AnalysisRules.defaults();
      when(() => repository.save(any())).thenAnswer((_) async {});
    });

    void buildEmits(List<BuildEvent> events) {
      when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
          .thenAnswer((_) => Stream.fromIterable(events));
    }

    AnalysisBloc bloc() => AnalysisBloc(repository: repository);

    const running = AnalysisRunning(
      label: 'AltMe',
      stage: BuildStage.fetching,
      fraction: 0,
    );

    test('events and states compare by value', () {
      // Constants are one instance: read the props themselves.
      expect(const AnalysisRetried().props, isEmpty);
      expect(const AnalysisCancelled().props, isEmpty);
      expect(const AnalysisDismissed().props, isEmpty);
      expect(const AnalysisIdle().props, isEmpty);
      expect(
        AnalysisStarted(source, rules),
        AnalysisStarted(source, AnalysisRules.defaults()),
      );
      expect(const AnalysisIdle(), const AnalysisIdle());
      expect(const AnalysisSucceeded('a'), isNot(const AnalysisSucceeded('b')));
    });

    test('starts idle', () {
      expect(bloc().state, const AnalysisIdle());
    });

    group('AnalysisStarted', () {
      blocTest<AnalysisBloc, AnalysisState>(
        'reports every stage, saves the map and succeeds',
        setUp: () => buildEmits([
          const BuildProgress(BuildStage.fetching, 0.1),
          const BuildProgress(
            BuildStage.analyzing,
            0.4,
            detail: 'lib/main.dart',
          ),
          const BuildProgress(BuildStage.layingOut, 0.8),
          BuildSucceeded(file),
        ]),
        build: bloc,
        act: (bloc) => bloc.add(AnalysisStarted(source, rules)),
        expect: () => [
          running,
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.fetching,
            fraction: 0.1,
          ),
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.analyzing,
            fraction: 0.4,
            detail: 'lib/main.dart',
          ),
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.layingOut,
            fraction: 0.8,
          ),
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.encoding,
            fraction: 1,
          ),
          const AnalysisSucceeded('9-z'),
        ],
        verify: (_) => verify(() => repository.save(file)).called(1),
      );

      blocTest<AnalysisBloc, AnalysisState>(
        'builds with the source and the rules it was given',
        setUp: () => buildEmits([BuildSucceeded(file)]),
        build: bloc,
        act: (bloc) => bloc.add(AnalysisStarted(source, rules)),
        verify: (_) => verify(
          () => repository.build(source, rules, cancel: any(named: 'cancel')),
        ).called(1),
      );

      blocTest<AnalysisBloc, AnalysisState>(
        'fails with the repository failure',
        setUp: () => buildEmits(const [
          BuildProgress(BuildStage.fetching, 0.1),
          BuildFailed(BuildFailure(BuildFailureKind.network, 'offline')),
        ]),
        build: bloc,
        act: (bloc) => bloc.add(AnalysisStarted(source, rules)),
        expect: () => [
          running,
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.fetching,
            fraction: 0.1,
          ),
          const AnalysisFailed(
            BuildFailure(BuildFailureKind.network, 'offline'),
          ),
        ],
        verify: (_) => verifyNever(() => repository.save(any())),
      );

      blocTest<AnalysisBloc, AnalysisState>(
        'goes back to idle when the repository reports a cancellation',
        setUp: () => buildEmits(const [
          BuildFailed(BuildFailure(BuildFailureKind.cancelled, 'cancelled')),
        ]),
        build: bloc,
        act: (bloc) => bloc.add(AnalysisStarted(source, rules)),
        expect: () => [running, const AnalysisIdle()],
      );

      blocTest<AnalysisBloc, AnalysisState>(
        'fails when the map cannot be saved',
        setUp: () {
          buildEmits([BuildSucceeded(file)]);
          when(() => repository.save(any())).thenThrow(
            const BuildFailure(BuildFailureKind.storage, 'disk full'),
          );
        },
        build: bloc,
        act: (bloc) => bloc.add(AnalysisStarted(source, rules)),
        expect: () => [
          running,
          const AnalysisRunning(
            label: 'AltMe',
            stage: BuildStage.encoding,
            fraction: 1,
          ),
          const AnalysisFailed(
            BuildFailure(BuildFailureKind.storage, 'disk full'),
          ),
        ],
      );

      test('is ignored while an analysis runs', () async {
        final events = StreamController<BuildEvent>();
        when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
            .thenAnswer((_) => events.stream);
        final subject = bloc()..add(AnalysisStarted(source, rules));
        await pumpEventQueue();

        subject.add(AnalysisStarted(source, rules));
        await pumpEventQueue();

        verify(
          () => repository.build(any(), any(), cancel: any(named: 'cancel')),
        ).called(1);
        await events.close();
        await subject.close();
      });
    });

    group('AnalysisCancelled', () {
      test('returns to idle at once and cancels the build', () async {
        final events = StreamController<BuildEvent>();
        CancelToken? token;
        when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
            .thenAnswer((invocation) {
              token = invocation.namedArguments[#cancel] as CancelToken;
              return events.stream;
            });
        final subject = bloc()..add(AnalysisStarted(source, rules));
        await pumpEventQueue();

        subject.add(const AnalysisCancelled());
        await pumpEventQueue();

        expect(subject.state, const AnalysisIdle());
        expect(token!.isCancelled, isTrue);
        await events.close();
        await subject.close();
      });

      test('ignores what the build still reports', () async {
        final events = StreamController<BuildEvent>();
        when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
            .thenAnswer((_) => events.stream);
        final subject = bloc()..add(AnalysisStarted(source, rules));
        await pumpEventQueue();
        subject.add(const AnalysisCancelled());
        await pumpEventQueue();
        final states = <AnalysisState>[];
        final subscription = subject.stream.listen(states.add);

        events
          ..add(const BuildProgress(BuildStage.layingOut, 0.8))
          ..add(BuildSucceeded(file))
          ..add(
            const BuildFailed(
              BuildFailure(BuildFailureKind.cancelled, 'cancelled'),
            ),
          );
        await events.close();
        await pumpEventQueue();

        expect(states, isEmpty);
        verifyNever(() => repository.save(any()));
        await subscription.cancel();
        await subject.close();
      });

      blocTest<AnalysisBloc, AnalysisState>(
        'does nothing when nothing runs',
        build: bloc,
        act: (bloc) => bloc.add(const AnalysisCancelled()),
        expect: () => <AnalysisState>[],
      );
    });

    group('AnalysisRetried', () {
      blocTest<AnalysisBloc, AnalysisState>(
        'runs the last analysis again',
        setUp: () => buildEmits(const [
          BuildFailed(BuildFailure(BuildFailureKind.network, 'offline')),
        ]),
        build: bloc,
        act: (bloc) async {
          bloc.add(AnalysisStarted(source, rules));
          await pumpEventQueue();
          bloc.add(const AnalysisRetried());
        },
        verify: (_) => verify(
          () => repository.build(source, rules, cancel: any(named: 'cancel')),
        ).called(2),
        expect: () => [
          running,
          const AnalysisFailed(
            BuildFailure(BuildFailureKind.network, 'offline'),
          ),
          running,
          const AnalysisFailed(
            BuildFailure(BuildFailureKind.network, 'offline'),
          ),
        ],
      );

      blocTest<AnalysisBloc, AnalysisState>(
        'does nothing before any analysis',
        build: bloc,
        act: (bloc) => bloc.add(const AnalysisRetried()),
        expect: () => <AnalysisState>[],
      );

      test('is ignored while an analysis runs', () async {
        final events = StreamController<BuildEvent>();
        when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
            .thenAnswer((_) => events.stream);
        final subject = bloc()..add(AnalysisStarted(source, rules));
        await pumpEventQueue();

        subject.add(const AnalysisRetried());
        await pumpEventQueue();

        verify(
          () => repository.build(any(), any(), cancel: any(named: 'cancel')),
        ).called(1);
        await events.close();
        await subject.close();
      });
    });

    group('AnalysisDismissed', () {
      blocTest<AnalysisBloc, AnalysisState>(
        'leaves a failure for the form',
        setUp: () => buildEmits(const [
          BuildFailed(BuildFailure(BuildFailureKind.network, 'offline')),
        ]),
        build: bloc,
        act: (bloc) async {
          bloc.add(AnalysisStarted(source, rules));
          await pumpEventQueue();
          bloc.add(const AnalysisDismissed());
        },
        skip: 2,
        expect: () => [const AnalysisIdle()],
      );
    });

    test('cancels a running build when it is closed', () async {
      final events = StreamController<BuildEvent>();
      CancelToken? token;
      when(() => repository.build(any(), any(), cancel: any(named: 'cancel')))
          .thenAnswer((invocation) {
            token = invocation.namedArguments[#cancel] as CancelToken;
            return events.stream;
          });
      final subject = bloc()..add(AnalysisStarted(source, rules));
      await pumpEventQueue();

      await subject.close();

      expect(token!.isCancelled, isTrue);
      await events.close();
    });
  });
}
