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
