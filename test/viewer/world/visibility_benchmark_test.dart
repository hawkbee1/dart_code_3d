// Benchmarks of resolveVisibility on maps the size of AltMe's (11k nodes,
// 7k links) and far beyond it (100k links). Slow and machine dependent, so
// tagged `slow`: run them with `-t slow`. To measure a real map, also pass
// `--dart-define=DC3D_BENCH_MAP=<path of a .dc3d>`.

import 'dart:io';

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_tags.dart';

const _realMap = String.fromEnvironment('DC3D_BENCH_MAP');

/// A project of [classes] classes with [membersPerClass] methods each and
/// [links] random calls between methods (a fixed seed: the same every run).
CodeMap syntheticMap({
  required int classes,
  required int membersPerClass,
  required int links,
}) {
  final nodes = <String, CodeNode>{};
  final placements = <String, Placement>{};
  final members = <String>[];
  const placement = Placement(x: 0, y: 0, z: 0, radius: 1);
  for (var c = 0; c < classes; c++) {
    final id = 'c$c';
    nodes[id] = CodeNode(id: id, kind: CodeNodeKind.classDecl, name: id);
    placements[id] = placement;
    for (var m = 0; m < membersPerClass; m++) {
      final memberId = '$id.m$m';
      nodes[memberId] = CodeNode(
        id: memberId,
        kind: CodeNodeKind.method,
        name: memberId,
        parentId: id,
      );
      placements[memberId] = placement;
      members.add(memberId);
    }
  }
  var seed = 12345;
  int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return CodeMap(
    graph: CodeGraph(
      project: ProjectInfo(
        generator: 'benchmark',
        source: const LocalFolderDescriptor(name: 'synthetic'),
        createdAt: DateTime.utc(2026, 10, 4),
      ),
      nodes: nodes,
      links: [
        for (var i = 0; i < links; i++)
          CodeLink(
            fromId: members[next() % members.length],
            toId: members[next() % members.length],
            kind: LinkKind.call,
            resolution: i % 7 == 0
                ? LinkResolution.ambiguous
                : LinkResolution.exact,
            count: 1 + next() % 4,
          ),
      ],
    ),
    placements: placements,
  );
}

/// The median time, in milliseconds, of [runs] calls of [action].
double medianMs(int runs, void Function() action) {
  final times = <double>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    action();
    times.add(watch.elapsedMicroseconds / 1000);
  }
  return (times..sort())[runs ~/ 2];
}

/// What a map costs: the index once, then each kind of view.
({
  double indexMs,
  double topLevelMs,
  double interiorMs,
  double windowMs,
  double focusMs,
  int maxLinks,
})
measure(CodeMap map, {int containersToScan = 60}) {
  final watch = Stopwatch()..start();
  final index = VisibilityIndex(map);
  final indexMs = watch.elapsedMicroseconds / 1000;
  const kinds = {...LinkKind.values};
  VisibleWorld resolve(String? container, ViewMode mode, [String? selected]) =>
      resolveVisibility(
        index: index,
        containerId: container,
        mode: mode,
        linkKinds: kinds,
        selectedId: selected,
      );
  final containers = [
    for (final node in map.graph.nodes.values)
      if (map.graph.childrenOf(node.id).isNotEmpty) node.id,
  ];
  final busiest = containers.first;
  final scanned = containers.take(containersToScan);
  var maxLinks = resolve(null, ViewMode.interior).links.length;
  for (final container in scanned) {
    for (final mode in ViewMode.values) {
      final links = resolve(container, mode).links.length;
      if (links > maxLinks) maxLinks = links;
    }
  }
  return (
    indexMs: indexMs,
    topLevelMs: medianMs(15, () => resolve(null, ViewMode.interior)),
    interiorMs: medianMs(15, () => resolve(busiest, ViewMode.interior)),
    windowMs: medianMs(15, () => resolve(busiest, ViewMode.window)),
    focusMs: medianMs(
      15,
      () => resolve(null, ViewMode.interior, map.graph.topLevel.first.id),
    ),
    maxLinks: maxLinks,
  );
}

void main() {
  group('resolveVisibility', () {
    void report(String name, CodeMap map, Object result) {
      // The numbers are read from the test log.
      // ignore: avoid_print
      print(
        'BENCH $name: ${map.graph.nodes.length} nodes, '
        '${map.graph.links.length} links → $result',
      );
    }

    test(
      'resolves a map the size of AltMe in under 30 ms',
      tags: TestTag.slow,
      () {
        final map = syntheticMap(
          classes: 1500,
          membersPerClass: 6,
          links: 7400,
        );

        final result = measure(map);

        report('altme-sized', map, result);
        expect(result.topLevelMs, lessThan(30));
        expect(result.interiorMs, lessThan(30));
        expect(result.windowMs, lessThan(30));
        expect(result.focusMs, lessThan(30));
      },
    );

    test('stays usable with 100k links', tags: TestTag.slow, () {
      final map = syntheticMap(
        classes: 1500,
        membersPerClass: 6,
        links: 100000,
      );

      final result = measure(map, containersToScan: 20);

      report('100k-links', map, result);
      expect(result.topLevelMs, lessThan(250));
      expect(result.windowMs, lessThan(250));
    });

    test(
      'resolves a real map',
      tags: TestTag.slow,
      skip: _realMap.isEmpty
          ? 'pass --dart-define=DC3D_BENCH_MAP=<path>'
          : null,
      () {
        final map = const CodeMapCodec().decodeFromBytes(
          File(_realMap).readAsBytesSync(),
        );

        final result = measure(map, containersToScan: 400);

        report(_realMap.split('/').last, map, result);
        expect(result.topLevelMs, lessThan(30));
      },
    );
  });
}
