import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/code_maps.dart';

VisibleLink _link(
  String from,
  String to, {
  LinkKind kind = LinkKind.call,
  int count = 1,
  bool aggregated = false,
  bool dim = false,
}) => VisibleLink(
  fromId: from,
  toId: to,
  kind: kind,
  count: count,
  aggregated: aggregated,
  dim: dim,
);

void main() {
  group(resolveVisibility, () {
    late VisibilityIndex index;
    const all = {...LinkKind.values};

    setUp(() => index = VisibilityIndex.of(nestedMap()));

    VisibleWorld resolve({
      String? container,
      ViewMode mode = ViewMode.interior,
      Set<LinkKind> kinds = all,
      String? selected,
    }) => resolveVisibility(
      index: index,
      containerId: container,
      mode: mode,
      linkKinds: kinds,
      selectedId: selected,
    );

    group('at the top level', () {
      test('shows the top-level spheres and remaps links to them', () {
        final world = resolve();

        expect(world.openContainers, isEmpty);
        expect(world.visibleSpheres, ['main', 'A', 'C', 'G', 'pkg']);
        expect(world.links, [
          _link('main', 'A', aggregated: true),
          // Two links merge: one exact, one ambiguous: not dim as a whole.
          _link('A', 'C', count: 2, aggregated: true),
          _link('C', 'pkg', aggregated: true, dim: true),
          _link('G', 'A', aggregated: true),
          _link('A', 'C', kind: LinkKind.implementsLink, aggregated: true),
          _link('main', 'A', kind: LinkKind.import),
        ]);
      });

      test('drops links whose ends are inside the same sphere', () {
        final links = resolve().links;

        // A.m → A.B.n, both inside A.
        expect(links.any((l) => l.fromId == l.toId), isFalse);
        expect(links.where((l) => l.fromId == 'A' && l.toId == 'A'), isEmpty);
      });

      test('is the same in window view', () {
        expect(resolve(mode: ViewMode.window), resolve());
      });

      test('keeps only the enabled link kinds', () {
        expect(
          resolve(kinds: {LinkKind.call}).links.map((l) => l.kind).toSet(),
          {LinkKind.call},
        );
        expect(resolve(kinds: {LinkKind.import}).links, [
          _link('main', 'A', kind: LinkKind.import),
        ]);
        expect(resolve(kinds: {}).links, isEmpty);
      });
    });

    group('focus mode', () {
      test('keeps the links touching the selected sphere', () {
        final links = resolve(selected: 'pkg').links;

        expect(links, [_link('C', 'pkg', aggregated: true, dim: true)]);
      });

      test('selects through the visible ancestor of a hidden node', () {
        final links = resolve(selected: 'A.m').links;

        expect(links, isNotEmpty);
        expect(links.every((l) => l.fromId == 'A' || l.toId == 'A'), isTrue);
        expect(links.any((l) => l.fromId == 'C' && l.toId == 'pkg'), isFalse);
      });

      test('is ignored when the selected node is not visible', () {
        expect(
          resolve(container: 'A', selected: 'C.k').links,
          resolve(container: 'A').links,
        );
      });
    });

    group('inside a container', () {
      test('interior view shows only its children', () {
        final world = resolve(container: 'A');

        expect(world.openContainers, ['A']);
        expect(world.visibleSpheres, ['A.m', 'A.B']);
        // Everything else is outside the visible world.
        expect(world.links, [_link('A.m', 'A.B', aggregated: true)]);
      });

      test('window view adds the rest of the world as closed spheres', () {
        final world = resolve(container: 'A', mode: ViewMode.window);

        expect(world.openContainers, ['A']);
        expect(world.visibleSpheres, ['main', 'C', 'G', 'pkg', 'A.m', 'A.B']);
        expect(world.links, [
          _link('main', 'A.m'),
          _link('A.m', 'C', aggregated: true),
          _link('A.B', 'C', aggregated: true, dim: true),
          _link('C', 'pkg', aggregated: true, dim: true),
          _link('G', 'A.m', aggregated: true),
          _link('A.B', 'C', kind: LinkKind.implementsLink),
          _link('A.m', 'A.B', aggregated: true),
        ]);
      });

      test('lists every open ancestor, outermost first', () {
        final interior = resolve(container: 'A.B');
        final window = resolve(container: 'A.B', mode: ViewMode.window);

        expect(interior.openContainers, ['A', 'A.B']);
        expect(interior.visibleSpheres, ['A.B.n']);
        expect(window.openContainers, ['A', 'A.B']);
        // Top level, the siblings of A.B inside A, and A.B's children.
        expect(window.visibleSpheres, [
          'main',
          'C',
          'G',
          'pkg',
          'A.m',
          'A.B.n',
        ]);
      });

      test('a ghost parent is a container too', () {
        final world = resolve(container: 'G', mode: ViewMode.window);

        expect(world.openContainers, ['G']);
        expect(world.visibleSpheres, ['main', 'A', 'C', 'pkg', 'G.D']);
        expect(world.links, contains(_link('G.D', 'A', aggregated: true)));
      });
    });
  });

  group(VisibilityIndex, () {
    test('is built once per map', () {
      final map = nestedMap();

      expect(VisibilityIndex.of(map), same(VisibilityIndex.of(map)));
      expect(VisibilityIndex.of(map), isNot(VisibilityIndex.of(nestedMap())));
    });

    test('gives the ancestor chain, node first', () {
      final index = VisibilityIndex.of(nestedMap());

      expect(index.chainOf('A.B.n'), ['A.B.n', 'A.B', 'A']);
      expect(index.chainOf('main'), ['main']);
    });

    test('lists the link kinds of the map in enum order', () {
      expect(VisibilityIndex.of(nestedMap()).linkKinds, [
        LinkKind.call,
        LinkKind.import,
        LinkKind.implementsLink,
      ]);
    });
  });

  group('value equality', () {
    test('visible worlds and links compare by value', () {
      // Built at runtime: equal const instances are identical, so their
      // props would never be read.
      VisibleLink link() => VisibleLink(
        fromId: 'a',
        toId: 'b',
        kind: LinkKind.call,
        count: [1, 2].length,
        aggregated: [true].isNotEmpty,
      );
      VisibleWorld world() => VisibleWorld(
        openContainers: List.of(const ['A']),
        visibleSpheres: List.of(const ['A.m']),
        links: [link()],
      );

      expect(link(), link());
      expect(world(), world());
      expect(link().props, hasLength(6));
      expect(world().props, hasLength(3));
    });
  });
}
