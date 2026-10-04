import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/code_maps.dart';

class _MockCodeMapRepository extends Mock implements CodeMapRepository;

void main() {
  group(ViewerBloc, () {
    late CodeMapRepository repository;
    late CodeMap map;
    final bytes = Uint8List.fromList([1, 2, 3]);
    final loadedAssets = <String>[];
    final readFiles = <String>[];

    setUpAll(() => registerFallbackValue(Uint8List(0)));

    setUp(() {
      repository = _MockCodeMapRepository();
      map = worldMap();
      loadedAssets.clear();
      readFiles.clear();
      when(() => repository.openBytes(any())).thenAnswer((_) async => map);
    });

    ViewerBloc build() => ViewerBloc(
      repository: repository,
      loadAsset: (key) async {
        loadedAssets.add(key);
        return ByteData.sublistView(bytes);
      },
      readFile: (path) async {
        readFiles.add(path);
        return bytes;
      },
    );

    test('starts loading', () {
      expect(build().state, const ViewerLoading());
    });

    group(ViewerOpened, () {
      blocTest<ViewerBloc, ViewerState>(
        'opens an asset',
        build: build,
        act: (bloc) => bloc.add(const ViewerOpened(CodeMapSource.sample)),
        expect: () => [ViewerReady(map: map)],
        verify: (_) {
          expect(loadedAssets, [CodeMapSource.sample.path]);
          verify(() => repository.openBytes(bytes)).called(1);
        },
      );

      blocTest<ViewerBloc, ViewerState>(
        'opens bytes',
        build: build,
        act: (bloc) => bloc.add(ViewerOpened(BytesCodeMapSource('a', bytes))),
        expect: () => [ViewerReady(map: map)],
        verify: (_) => expect(loadedAssets, isEmpty),
      );

      blocTest<ViewerBloc, ViewerState>(
        'opens a local file',
        build: build,
        act: (bloc) =>
            bloc.add(const ViewerOpened(LocalFileCodeMapSource('/m.dc3d'))),
        expect: () => [ViewerReady(map: map)],
        verify: (_) => expect(readFiles, ['/m.dc3d']),
      );

      blocTest<ViewerBloc, ViewerState>(
        'reloads when opened again',
        build: build,
        seed: () => ViewerReady(map: map),
        act: (bloc) => bloc.add(const ViewerOpened(CodeMapSource.sample)),
        expect: () => [const ViewerLoading(), ViewerReady(map: map)],
      );

      blocTest<ViewerBloc, ViewerState>(
        'fails on a file that is not a code map',
        setUp: () => when(() => repository.openBytes(any())).thenThrow(
          const BuildFailure(BuildFailureKind.invalidFile, 'Not gzip.'),
        ),
        build: build,
        act: (bloc) => bloc.add(const ViewerOpened(CodeMapSource.sample)),
        expect: () => [const ViewerFailure('Not gzip.')],
      );

      blocTest<ViewerBloc, ViewerState>(
        'fails when the file cannot be read',
        build: () => ViewerBloc(
          repository: repository,
          loadAsset: (_) async => throw StateError('no asset'),
          readFile: (_) async => bytes,
        ),
        act: (bloc) => bloc.add(const ViewerOpened(CodeMapSource.sample)),
        expect: () => [const ViewerFailure('Bad state: no asset')],
      );
    });

    group('once ready', () {
      blocTest<ViewerBloc, ViewerState>(
        'stores the container, the selection and the toggles',
        build: build,
        seed: () => ViewerReady(map: map),
        act: (bloc) => bloc
          ..add(const ViewerContainerChanged('A'))
          ..add(const ViewerNodeSelected('A.m'))
          ..add(const ViewerViewModeToggled())
          ..add(const ViewerLinkKindToggled(LinkKind.call))
          ..add(const ViewerLabelsToggled())
          ..add(const ViewerViewModeToggled())
          ..add(const ViewerLinkKindToggled(LinkKind.call))
          ..add(const ViewerNodeSelected(null))
          ..add(const ViewerContainerChanged(null)),
        expect: () {
          final ready = ViewerReady(map: map);
          final inA = ready.copyWith(currentContainerId: () => 'A');
          final selected = inA.copyWith(selectedId: () => 'A.m');
          final window = selected.copyWith(viewMode: ViewMode.window);
          final noCalls = window.copyWith(
            visibleLinkKinds: {...LinkKind.values}..remove(LinkKind.call),
          );
          final noLabels = noCalls.copyWith(labelsOn: false);
          final interior = noLabels.copyWith(viewMode: ViewMode.interior);
          final calls = interior.copyWith(
            visibleLinkKinds: {...LinkKind.values},
          );
          final unselected = calls.copyWith(selectedId: () => null);
          return [
            inA,
            selected,
            window,
            noCalls,
            noLabels,
            interior,
            calls,
            unselected,
            unselected.copyWith(currentContainerId: () => null),
          ];
        },
      );

      blocTest<ViewerBloc, ViewerState>(
        'ignores view events before a map is open',
        build: build,
        act: (bloc) => bloc
          ..add(const ViewerNodeSelected('A'))
          ..add(const ViewerLabelsToggled()),
        expect: () => <ViewerState>[],
      );
    });

    test('events and states compare by value', () {
      final events = [
        const ViewerOpened(CodeMapSource.sample),
        const ViewerContainerChanged('A'),
        const ViewerNodeSelected('A'),
        const ViewerViewModeToggled(),
        const ViewerLinkKindToggled(LinkKind.import),
        const ViewerLabelsToggled(),
      ];
      for (final event in events) {
        expect(event.props, isA<List<Object?>>());
      }
      expect(const ViewerLoading().props, isEmpty);
      expect(const ViewerFailure('x').props, ['x']);
      expect(ViewerReady(map: map).props, hasLength(6));
    });
  });
}
