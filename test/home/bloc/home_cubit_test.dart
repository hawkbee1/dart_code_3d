import 'dart:async';
import 'dart:typed_data';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/bloc/home_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(HomeCubit, () {
    late MockCodeMapRepository repository;
    late MockFileDialogs dialogs;
    late MockFileExporter exporter;
    late StreamController<void> changes;
    late List<CodeMapSummary> stored;
    late CodeMapFile file;

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(ExportMode.share);
    });

    setUp(() {
      stored = recentSummaries();
      changes = StreamController<void>.broadcast(sync: true);
      repository = repositoryWith(maps: stored, changes: changes.stream);
      dialogs = MockFileDialogs();
      exporter = MockFileExporter();
      file = codeMapFileOf(id: '9-z');
      when(() => repository.load(any())).thenAnswer((_) async => file);
      when(
        () => exporter.export(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() => changes.close());

    HomeCubit cubit({ExportMode mode = ExportMode.saveFile}) => HomeCubit(
      repository: repository,
      dialogs: dialogs,
      exporter: exporter,
      exportMode: mode,
    );

    Future<HomeCubit> started() async {
      final subject = cubit();
      await subject.started();
      addTearDown(subject.close);
      return subject;
    }

    test('starts loading, with no map', () async {
      final subject = cubit();
      addTearDown(subject.close);

      expect(subject.state, const HomeState());
      expect(subject.state.status, HomeStatus.loading);
    });

    group('started', () {
      test('lists the stored maps', () async {
        final subject = await started();

        expect(subject.state.status, HomeStatus.ready);
        expect(subject.state.maps, stored);
      });

      test('reports a store that cannot be read, and recovers', () async {
        when(repository.recent)
            .thenThrow(const BuildFailure(BuildFailureKind.storage, 'disk'));
        final subject = cubit();
        addTearDown(subject.close);

        await subject.started();
        expect(subject.state.status, HomeStatus.failure);

        when(repository.recent).thenAnswer((_) async => stored);
        await subject.started();
        expect(subject.state.status, HomeStatus.ready);
      });
    });

    group('when a map is saved or deleted anywhere', () {
      test('lists the maps again', () async {
        final subject = await started();
        final fewer = stored.take(2).toList();
        when(repository.recent).thenAnswer((_) async => fewer);

        changes.add(null);
        await pumpEventQueue();

        expect(subject.state.maps, fewer);
      });

      test('stops listening once closed', () async {
        final subject = await started();
        await subject.close();
        clearInteractions(repository);

        changes.add(null);
        await pumpEventQueue();

        verifyNever(repository.recent);
      });

      test('does not emit when the list arrives after it was closed', () async {
        final gate = Completer<List<CodeMapSummary>>();
        final subject = await started();
        when(repository.recent).thenAnswer((_) => gate.future);
        changes.add(null);

        await subject.close();
        gate.complete(const []);
        await pumpEventQueue();

        expect(subject.state.maps, stored);
      });

      test('does not emit when the store fails after it was closed', () async {
        final gate = Completer<List<CodeMapSummary>>();
        final subject = await started();
        when(repository.recent).thenAnswer((_) => gate.future);
        changes.add(null);

        await subject.close();
        gate.completeError(
          const BuildFailure(BuildFailureKind.storage, 'disk'),
        );
        await pumpEventQueue();

        expect(subject.state.status, HomeStatus.ready);
      });
    });

    group('deleted', () {
      test('deletes the map and offers to undo it', () async {
        final subject = await started();

        await subject.deleted('9-z');

        verify(() => repository.delete('9-z')).called(1);
        expect(subject.state.notice, HomeMapDeleted(file, serial: 1));
      });

      test('says nothing about a map that was already gone', () async {
        when(() => repository.load(any())).thenAnswer((_) async => null);
        final subject = await started();

        await subject.deleted('9-z');

        expect(subject.state.notice, isNull);
      });

      test('reports a failure', () async {
        const failure = BuildFailure(BuildFailureKind.storage, 'disk');
        when(() => repository.delete(any())).thenThrow(failure);
        final subject = await started();

        await subject.deleted('9-z');

        expect(subject.state.notice, const HomeFailed(failure, serial: 1));
      });

      test('numbers its notices, so equal ones are both shown', () async {
        final subject = await started();

        await subject.deleted('9-z');
        final first = subject.state.notice;
        await subject.deleted('9-z');

        expect(subject.state.notice, isNot(first));
        expect(subject.state.notice, HomeMapDeleted(file, serial: 2));
      });
    });

    group('deletionUndone', () {
      test('puts the map back', () async {
        final subject = await started();

        await subject.deletionUndone(file);

        verify(() => repository.save(file)).called(1);
        expect(subject.state.notice, isNull);
      });

      test('reports a failure', () async {
        const failure = BuildFailure(BuildFailureKind.storage, 'disk');
        when(() => repository.save(any())).thenThrow(failure);
        final subject = await started();

        await subject.deletionUndone(file);

        expect(subject.state.notice, const HomeFailed(failure, serial: 1));
      });
    });

    group('fileOpened', () {
      final picked = PickedFile(name: 'AltMe.dc3d', bytes: Uint8List(5));

      test('imports and stores the picked file, and returns its id', () async {
        when(dialogs.pickCodeMap).thenAnswer((_) async => picked);
        when(() => repository.importBytes(any(), any()))
            .thenAnswer((_) async => file);
        final subject = await started();

        final id = await subject.fileOpened();

        expect(id, '9-z');
        verify(() => repository.importBytes('AltMe.dc3d', picked.bytes))
            .called(1);
        verify(() => repository.save(file)).called(1);
      });

      test('does nothing when the user cancels', () async {
        when(dialogs.pickCodeMap).thenAnswer((_) async => null);
        final subject = await started();

        expect(await subject.fileOpened(), isNull);

        verifyNever(() => repository.importBytes(any(), any()));
        expect(subject.state.notice, isNull);
      });

      test('says why a file is unusable', () async {
        const failure = BuildFailure(BuildFailureKind.invalidFile, 'newer');
        when(dialogs.pickCodeMap).thenAnswer((_) async => picked);
        when(() => repository.importBytes(any(), any())).thenThrow(failure);
        final subject = await started();

        expect(await subject.fileOpened(), isNull);

        expect(subject.state.notice, const HomeFailed(failure, serial: 1));
        verifyNever(() => repository.save(any()));
      });
    });

    group('exported', () {
      setUp(() {
        when(() => repository.exportForSharing(any())).thenReturn((
          fileName: 'AltMe.dc3d',
          bytes: Uint8List.fromList([1, 2]),
        ));
      });

      for (final mode in ExportMode.values) {
        test('hands the file over as the platform does it ($mode)', () async {
          final subject = cubit(mode: mode);
          addTearDown(subject.close);

          await subject.exported('9-z');

          verify(
            () => exporter.export(
              fileName: 'AltMe.dc3d',
              bytes: Uint8List.fromList([1, 2]),
              mode: mode,
            ),
          ).called(1);
        });
      }

      test('does nothing for a map that is gone', () async {
        when(() => repository.load(any())).thenAnswer((_) async => null);
        final subject = await started();

        await subject.exported('9-z');

        verifyNever(
          () => exporter.export(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            mode: any(named: 'mode'),
          ),
        );
        expect(subject.state.notice, isNull);
      });

      test('reports a store that cannot be read', () async {
        const failure = BuildFailure(BuildFailureKind.storage, 'disk');
        when(() => repository.load(any())).thenThrow(failure);
        final subject = await started();

        await subject.exported('9-z');

        expect(subject.state.notice, const HomeFailed(failure, serial: 1));
      });

      test('reports a share sheet or a dialog that fails', () async {
        when(
          () => exporter.export(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            mode: any(named: 'mode'),
          ),
        ).thenThrow(StateError('no share sheet'));
        final subject = await started();

        await subject.exported('9-z');

        expect(subject.state.notice, const HomeExportFailed(serial: 1));
      });
    });
  });
}
