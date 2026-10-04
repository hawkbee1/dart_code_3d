import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(buildSceneContent, () {
    late CodeMap map;
    late Map<String, Vector3> positions;
    late VisibilityIndex index;

    setUp(() {
      map = nestedMap();
      positions = worldPositions(map);
      index = VisibilityIndex.of(map);
    });

    SceneContent build({
      String? container,
      ViewMode mode = ViewMode.interior,
      double scale = 10,
    }) => buildSceneContent(
      map: map,
      positions: positions,
      colors: CodeWorldColors.light,
      visible: resolveVisibility(
        index: index,
        containerId: container,
        mode: mode,
        linkKinds: {...LinkKind.values},
      ),
      mode: mode,
      scale: scale,
    );

    test('groups the spheres by material', () {
      final content = build();

      expect(content.solid.map((s) => s.nodeId), ['main', 'A', 'C']);
      expect(content.ghosts.map((s) => s.nodeId), ['G']);
      expect(content.packages.map((s) => s.nodeId), ['pkg']);
      expect(content.sphereCount, 5);
      expect(content.shells, isEmpty);
    });

    test('colors spheres by kind, in linear space', () {
      final solid = build().solid;

      expect(
        solid.first.color,
        linearColor(CodeWorldColors.light.nodes[CodeNodeKind.function]!),
      );
      expect(solid.last.radius, 3);
      expect(solid.last.center, Vector3(20, 0, 0));
    });

    test('draws the shell of the current container as a tinted dome', () {
      final content = build(container: 'A.B');

      expect(content.shells, hasLength(1));
      expect(content.shells.single.sphere.nodeId, 'A.B');
      expect(content.shells.single.opacity, interiorShellOpacity);
      expect(content.solid.map((s) => s.nodeId), ['A.B.n']);
    });

    test('window view draws every open shell almost transparent', () {
      final content = build(container: 'A.B', mode: ViewMode.window);

      expect(content.shells.map((s) => s.sphere.nodeId), ['A', 'A.B']);
      expect(
        content.shells.map((s) => s.opacity),
        everyElement(windowShellOpacity),
      );
      expect(windowShellOpacity, lessThan(interiorShellOpacity));
    });

    test('groups links by kind, width and dimness, joining the surfaces', () {
      final content = build();

      final batches = content.links.keys.toSet();
      expect(
        batches,
        containsAll([
          const LinkBatch(kind: LinkKind.call, widthBucket: 0, dim: false),
          const LinkBatch(kind: LinkKind.call, widthBucket: 1, dim: false),
          const LinkBatch(kind: LinkKind.call, widthBucket: 0, dim: true),
          const LinkBatch(
            kind: LinkKind.implementsLink,
            widthBucket: 0,
            dim: false,
          ),
          const LinkBatch(kind: LinkKind.import, widthBucket: 0, dim: false),
        ]),
      );
      expect(content.linkCount, 6);
      // main (0,0,10, r .5) → A (0,0,0, r 3): from the surface of each.
      final (from, to) = content
          .links[const LinkBatch(
            kind: LinkKind.import,
            widthBucket: 0,
            dim: false,
          )]!
          .single;
      expect(from, Vector3(0, 0, 9.5));
      expect(to, Vector3(0, 0, 3));
    });

    test('centers on the spheres drawn, or on the container', () {
      final topLevel = build();
      final expected = Vector3.zero();
      for (final id in ['main', 'A', 'C', 'G', 'pkg']) {
        expected.add(positions[id]!);
      }
      expected.scale(1 / 5);

      expect(topLevel.center.distanceTo(expected), lessThan(1e-4));
      expect(build(container: 'C').center, positions['C']);
    });

    test('knows the typical sphere size', () {
      // Radii .5, 1.6, 3, 3 and 4 at the top level: the median is 3.
      expect(build().medianRadius, 3);
      // Alone inside A.B: its only child, A.B.n.
      expect(build(container: 'A.B').medianRadius, closeTo(0.3, 1e-9));
    });

    test('has a size and a center even when nothing is drawn', () {
      final empty = CodeMap(
        graph: CodeGraph(
          project: ProjectInfo(
            generator: 'test',
            source: const LocalFolderDescriptor(name: 'empty'),
            createdAt: DateTime.utc(2026, 10, 4),
          ),
          nodes: const {},
        ),
        placements: const {},
      );
      final content = buildSceneContent(
        map: empty,
        positions: const {},
        colors: CodeWorldColors.light,
        visible: const VisibleWorld(
          openContainers: [],
          visibleSpheres: [],
          links: [],
        ),
        mode: ViewMode.interior,
        scale: 1,
      );

      expect(content.sphereCount, 0);
      expect(content.medianRadius, 1);
      expect(content.center, Vector3.zero());
    });
  });

  group('link widths', () {
    SceneContent content({double medianRadius = 3, double scale = 100}) =>
        SceneContent(
          solid: const [],
          ghosts: const [],
          packages: const [],
          shells: const [],
          links: const {},
          center: Vector3.zero(),
          medianRadius: medianRadius,
          linkScale: scale,
        );

    test('are about two pixels wide at any distance', () {
      // 0.2% of the distance: two pixels of a 900 px, 45° view.
      expect(content().linkWidthFor(300), closeTo(0.6, 1e-9));
      expect(content().linkWidthFor(150), closeTo(0.3, 1e-9));
    });

    test('are never thinner than 3% of the typical sphere', () {
      expect(content().linkWidthFor(5), closeTo(0.09, 1e-9));
      expect(content().linkWidthFor(0), closeTo(0.09, 1e-9));
    });

    test('are never wider than 1% of the level', () {
      expect(content().linkWidthFor(100000), closeTo(1, 1e-9));
      expect(content(scale: 1000).linkWidthFor(100000), closeTo(10, 1e-9));
    });

    test('keep the floor in a level smaller than the spheres', () {
      expect(content(scale: 0.1).linkWidthFor(100000), closeTo(0.09, 1e-9));
    });

    test('are wider when they stand for more links', () {
      final links = content();

      expect(links.widthOf(0, 300), closeTo(0.6, 1e-9));
      expect(links.widthOf(1, 300), greaterThan(links.widthOf(0, 300)));
      expect(links.widthOf(2, 300), greaterThan(links.widthOf(1, 300)));
    });
  });

  group('widthBucketOf', () {
    test('widens with the number of merged links', () {
      expect(widthBucketOf(1), 0);
      expect([2, 3, 4].map(widthBucketOf), everyElement(1));
      expect([5, 50].map(widthBucketOf), everyElement(2));
    });
  });

  group('linkSegment', () {
    test('runs from surface to surface', () {
      final (from, to) = linkSegment(Vector3(0, 0, 0), 1, Vector3(10, 0, 0), 2);

      expect(from, Vector3(1, 0, 0));
      expect(to, Vector3(8, 0, 0));
    });

    test('joins the centers of touching or overlapping spheres', () {
      final a = Vector3(0, 0, 0);
      final b = Vector3(3, 0, 0);

      expect(linkSegment(a, 1, b, 2), (a, b));
      expect(linkSegment(a, 2, b, 2), (a, b));
    });
  });

  group('shellOpacity', () {
    test('fades in over 0.2 s up to the target', () {
      expect(shellOpacity(0, 0.25, animate: true), 0);
      expect(shellOpacity(0.1, 0.25, animate: true), closeTo(0.125, 1e-9));
      expect(shellOpacity(0.2, 0.25, animate: true), 0.25);
      expect(shellOpacity(5, 0.25, animate: true), 0.25);
    });

    test('shows at the target at once without animation', () {
      expect(shellOpacity(0, 0.25, animate: false), 0.25);
    });
  });

  group('value equality', () {
    test('shells and batches compare by value', () {
      LinkBatch batch() => LinkBatch(
        kind: LinkKind.call,
        widthBucket: [1].length,
        dim: [1].isEmpty,
      );
      ShellInstance shell() => ShellInstance(
        sphere: SphereInstance(
          nodeId: 'a',
          center: Vector3.zero(),
          radius: 1,
          color: Vector4.all(1),
        ),
        opacity: [0.25].first,
      );

      expect(batch(), batch());
      expect(batch().props, hasLength(3));
      expect(shell(), shell());
      expect(shell().props, hasLength(2));
    });
  });
}
