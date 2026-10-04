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
        'focuses on the selection only once asked, and only while selected',
        build: build,
        seed: () => ViewerReady(map: map),
        act: (bloc) => bloc
          // Nothing selected: nothing to focus on.
          ..add(const ViewerFocusToggled())
          ..add(const ViewerNodeSelected('A'))
          ..add(const ViewerFocusToggled())
          // Another selection keeps the focus.
          ..add(const ViewerNodeSelected('A.m'))
          ..add(const ViewerFocusToggled())
          ..add(const ViewerFocusToggled())
          ..add(const ViewerNodeSelected(null)),
        expect: () {
          final selected = ViewerReady(map: map, selectedId: 'A');
          final focused = selected.copyWith(focusOnSelected: true);
          final other = focused.copyWith(selectedId: () => 'A.m');
          return [
            selected,
            focused,
            other,
            other.copyWith(focusOnSelected: false),
            other.copyWith(focusOnSelected: true),
            ViewerReady(map: map),
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

    group('visible world', () {
      test('is derived from the container, mode, link kinds and selection', () {
        final ready = ViewerReady(map: nestedMap());
        final inA = ready.copyWith(currentContainerId: () => 'A');

        expect(ready.visible.openContainers, isEmpty);
        expect(ready.visible.visibleSpheres, hasLength(5));
        expect(inA.visible.openContainers, ['A']);
        expect(inA.visible.visibleSpheres, ['A.m', 'A.B']);
        expect(
          inA.copyWith(viewMode: ViewMode.window).visible.visibleSpheres,
          containsAll(['main', 'A.m', 'A.B']),
        );
        expect(ready.copyWith(visibleLinkKinds: {}).visible.links, isEmpty);
        // A selection alone changes nothing: focus is a separate choice.
        expect(
          ready.copyWith(selectedId: () => 'pkg').visible.links,
          hasLength(6),
        );
        expect(
          ready
              .copyWith(selectedId: () => 'pkg', focusOnSelected: true)
              .visible
              .links,
          hasLength(1),
        );
      });

      test('is worked out once per state', () {
        final ready = ViewerReady(map: nestedMap());

        expect(ready.visible, same(ready.visible));
        expect(
          ready.copyWith(labelsOn: false).visible,
          isNot(same(ready.visible)),
        );
      });

      blocTest<ViewerBloc, ViewerState>(
        'follows the events',
        build: build,
        seed: () => ViewerReady(map: nestedMap()),
        act: (bloc) => bloc
          ..add(const ViewerContainerChanged('A'))
          ..add(const ViewerViewModeToggled())
          ..add(const ViewerLinkKindToggled(LinkKind.call))
          ..add(const ViewerNodeSelected('A.m')),
        expect: () => [
          isA<ViewerReady>().having(
            (s) => s.visible.openContainers,
            'open containers',
            ['A'],
          ),
          isA<ViewerReady>().having(
            (s) => s.visible.visibleSpheres,
            'window view',
            contains('main'),
          ),
          isA<ViewerReady>().having(
            (s) => s.visible.links.map((l) => l.kind).toSet(),
            'link kinds without calls',
            isNot(contains(LinkKind.call)),
          ),
          isA<ViewerReady>().having(
            (s) => s.visible.links,
            'links after selecting a hidden node',
            isNotNull,
          ),
        ],
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
        const ViewerFocusToggled(),
      ];
      for (final event in events) {
        expect(event.props, isA<List<Object?>>());
      }
      expect(const ViewerLoading().props, isEmpty);
      expect(const ViewerFailure('x').props, ['x']);
      expect(ViewerReady(map: map).props, hasLength(7));
    });
  });
}
