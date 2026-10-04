import 'dart:io';

import 'package:code_graph/code_graph.dart';

/// A small world: `main` (the entry) in front, class `A` with a method
/// inside, and an external package far away.
CodeMap worldMap({String? entryNodeId = 'main'}) {
  final graph = CodeGraph(
    project: ProjectInfo(
      generator: 'test',
      source: const LocalFolderDescriptor(name: 'tiny_app'),
      createdAt: DateTime.utc(2026, 10, 4),
      entryNodeId: entryNodeId,
    ),
    nodes: {
      for (final node in const [
        CodeNode(id: 'main', kind: CodeNodeKind.function, name: 'main'),
        CodeNode(id: 'A', kind: CodeNodeKind.classDecl, name: 'A'),
        CodeNode(
          id: 'A.m',
          kind: CodeNodeKind.method,
          name: 'm',
          parentId: 'A',
        ),
        CodeNode(id: 'pkg', kind: CodeNodeKind.externalPackage, name: 'http'),
      ])
        node.id: node,
    },
    links: const [CodeLink(fromId: 'main', toId: 'A.m', kind: LinkKind.call)],
  );
  return CodeMap(
    graph: graph,
    placements: const {
      'main': Placement(x: 0, y: 0, z: 10, radius: 0.5),
      'A': Placement(x: 4, y: 0, z: 0, radius: 2),
      'A.m': Placement(x: 1, y: 0, z: 0, radius: 0.5),
      'pkg': Placement(x: -20, y: 0, z: 0, radius: 1.6),
    },
  );
}

/// The bundled sample map, read from disk.
CodeMap sampleMap() => const CodeMapCodec().decodeFromBytes(
  File('assets/samples/sample.dc3d').readAsBytesSync(),
);

/// A nested world for visibility tests (all radii are generous):
///
/// ```text
/// main (function)
/// A (class, r 3)       at (0,0,0)    A.m (method), A.B (class), A.B.n (method)
/// C (class, r 3)       at (20,0,0)   C.k (method)
/// G (ghost parent)     at (0,20,0)   G.D (class), G.D.p (method)
/// pkg (package)        at (-20,0,0)
/// ```
///
/// Links: `main → A.m` (call), `A.m → C.k` (call), `A.B.n → C.k` (call,
/// ambiguous), `C.k → pkg` (call, external), `G.D.p → A.m` (call),
/// `A.B → C` (implements), `main → A` (import), `A.m → A.B.n` (call).
CodeMap nestedMap() {
  const kinds = {
    'main': CodeNodeKind.function,
    'A': CodeNodeKind.classDecl,
    'A.m': CodeNodeKind.method,
    'A.B': CodeNodeKind.classDecl,
    'A.B.n': CodeNodeKind.method,
    'C': CodeNodeKind.classDecl,
    'C.k': CodeNodeKind.method,
    'G': CodeNodeKind.ghostParent,
    'G.D': CodeNodeKind.classDecl,
    'G.D.p': CodeNodeKind.method,
    'pkg': CodeNodeKind.externalPackage,
  };
  const parents = {
    'A.m': 'A',
    'A.B': 'A',
    'A.B.n': 'A.B',
    'C.k': 'C',
    'G.D': 'G',
    'G.D.p': 'G.D',
  };
  CodeLink call(
    String from,
    String to, [
    LinkResolution r = LinkResolution.exact,
  ]) => CodeLink(fromId: from, toId: to, kind: LinkKind.call, resolution: r);
  final graph = CodeGraph(
    project: ProjectInfo(
      generator: 'test',
      source: const LocalFolderDescriptor(name: 'nested'),
      createdAt: DateTime.utc(2026, 10, 4),
      entryNodeId: 'main',
    ),
    nodes: {
      for (final MapEntry(:key, :value) in kinds.entries)
        key: CodeNode(
          id: key,
          kind: value,
          name: key.split('.').last,
          parentId: parents[key],
        ),
    },
    links: [
      call('main', 'A.m'),
      call('A.m', 'C.k'),
      call('A.B.n', 'C.k', LinkResolution.ambiguous),
      call('C.k', 'pkg', LinkResolution.external),
      call('G.D.p', 'A.m'),
      const CodeLink(fromId: 'A.B', toId: 'C', kind: LinkKind.implementsLink),
      const CodeLink(fromId: 'main', toId: 'A', kind: LinkKind.import),
      call('A.m', 'A.B.n'),
    ],
  );
  return CodeMap(
    graph: graph,
    placements: const {
      'main': Placement(x: 0, y: 0, z: 10, radius: 0.5),
      'A': Placement(x: 0, y: 0, z: 0, radius: 3),
      'A.m': Placement(x: -1, y: 0, z: 0, radius: 0.5),
      'A.B': Placement(x: 1.5, y: 0, z: 0, radius: 1),
      'A.B.n': Placement(x: 0, y: 0.3, z: 0, radius: 0.3),
      'C': Placement(x: 20, y: 0, z: 0, radius: 3),
      'C.k': Placement(x: 0, y: 0, z: 0, radius: 0.5),
      'G': Placement(x: 0, y: 20, z: 0, radius: 4),
      'G.D': Placement(x: 0, y: 0, z: 0, radius: 1.5),
      'G.D.p': Placement(x: 0, y: 0, z: 0, radius: 0.4),
      'pkg': Placement(x: -20, y: 0, z: 0, radius: 1.6),
    },
  );
}

/// Nothing but an external package.
CodeMap onlyPackageMap() {
  final map = worldMap(entryNodeId: null);
  return CodeMap(
    graph: CodeGraph(
      project: map.graph.project,
      nodes: {'pkg': map.graph.nodes['pkg']!},
    ),
    placements: {'pkg': map.placements['pkg']!},
  );
}

/// [worldMap] without any link.
CodeMap mapWithoutLinks() {
  final map = worldMap();
  return CodeMap(
    graph: CodeGraph(project: map.graph.project, nodes: map.graph.nodes),
    placements: map.placements,
  );
}

/// Three nested classes with very long names, to test truncation.
CodeMap longNamesMap() {
  const names = {
    'A': 'AnExtremelyLongClassNameInAVeryNestedPackageStructure',
    'A.B': 'AnotherVeryLongNestedSubclassNameThatKeepsGoing',
    'A.B.C': 'ThirdLevelClassWithAnAbsurdlyLongNameToo',
    'A.B.C.m': 'method',
  };
  const parents = {'A.B': 'A', 'A.B.C': 'A.B', 'A.B.C.m': 'A.B.C'};
  return CodeMap(
    graph: CodeGraph(
      project: ProjectInfo(
        generator: 'test',
        source: const LocalFolderDescriptor(name: 'long_names'),
        createdAt: DateTime.utc(2026, 10, 4),
      ),
      nodes: {
        for (final MapEntry(:key, :value) in names.entries)
          key: CodeNode(
            id: key,
            kind: key == 'A.B.C.m'
                ? CodeNodeKind.method
                : CodeNodeKind.classDecl,
            name: value,
            parentId: parents[key],
          ),
      },
    ),
    placements: const {
      'A': Placement(x: 0, y: 0, z: 0, radius: 8),
      'A.B': Placement(x: 0, y: 0, z: 0, radius: 5),
      'A.B.C': Placement(x: 0, y: 0, z: 0, radius: 3),
      'A.B.C.m': Placement(x: 0, y: 0, z: 0, radius: 1),
    },
  );
}
