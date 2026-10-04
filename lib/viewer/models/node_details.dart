import 'package:code_graph/code_graph.dart';
import 'package:equatable/equatable.dart';

/// How many links there are of each [LinkResolution]: how far to trust them.
class ResolutionCounts extends Equatable {
  /// Creates counts.
  const new({
    this.exact = 0,
    this.byName = 0,
    this.ambiguous = 0,
    this.external = 0,
  });

  /// Resolved to the exact declaration.
  final int exact;

  /// Matched by name only (the type was unknown).
  final int byName;

  /// Several declarations had that name.
  final int ambiguous;

  /// Leaving the project.
  final int external;

  /// All the links.
  int get total => exact + byName + ambiguous + external;

  /// The count of [resolution].
  int of(LinkResolution resolution) => switch (resolution) {
    LinkResolution.exact => exact,
    LinkResolution.byName => byName,
    LinkResolution.ambiguous => ambiguous,
    LinkResolution.external => external,
  };

  /// These counts with one more link of [resolution].
  ResolutionCounts plusOne(LinkResolution resolution) => ResolutionCounts(
    exact: exact + (resolution == LinkResolution.exact ? 1 : 0),
    byName: byName + (resolution == LinkResolution.byName ? 1 : 0),
    ambiguous: ambiguous + (resolution == LinkResolution.ambiguous ? 1 : 0),
    external: external + (resolution == LinkResolution.external ? 1 : 0),
  );

  @override
  List<Object?> get props => [exact, byName, ambiguous, external];
}

/// The links of one kind that leave and enter a node.
class LinkKindStats extends Equatable {
  /// Creates the statistics.
  const new({
    required this.kind,
    required this.outgoing,
    required this.incoming,
  });

  /// The link kind.
  final LinkKind kind;

  /// Links starting inside the node.
  final ResolutionCounts outgoing;

  /// Links ending inside the node.
  final ResolutionCounts incoming;

  @override
  List<Object?> get props => [kind, outgoing, incoming];
}

/// What the info panel shows about a node.
class NodeDetails extends Equatable {
  /// Creates details.
  const new({
    required this.id,
    required this.name,
    required this.qualifiedName,
    required this.kind,
    required this.loc,
    required this.members,
    required this.nested,
    required this.links,
    this.filePath,
    this.startLine,
    this.endLine,
    this.packageName,
  });

  /// Reads the details of node [id] in [map].
  ///
  /// The links are those that cross the boundary of the node and everything
  /// inside it, the ones the 3D view draws for it; links between two things
  /// inside the node are left out.
  factory of(CodeMap map, String id) {
    final graph = map.graph;
    final node = graph.nodes[id]!;
    final children = graph.childrenOf(id);
    const memberKinds = {
      CodeNodeKind.method,
      CodeNodeKind.constructor,
      CodeNodeKind.getter,
      CodeNodeKind.setter,
    };

    final subtree = <String>{};
    final pending = [id];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (subtree.add(next)) {
        pending.addAll(graph.childrenOf(next).map((n) => n.id));
      }
    }
    final outgoing = <LinkKind, ResolutionCounts>{};
    final incoming = <LinkKind, ResolutionCounts>{};
    for (final link in graph.links) {
      final from = subtree.contains(link.fromId);
      final to = subtree.contains(link.toId);
      if (from == to) continue;
      final counts = from ? outgoing : incoming;
      counts[link.kind] = (counts[link.kind] ?? const ResolutionCounts())
          .plusOne(link.resolution);
    }

    return NodeDetails(
      id: id,
      name: node.name,
      qualifiedName: node.qualifiedName,
      kind: node.kind,
      loc: node.loc,
      members: children.where((c) => memberKinds.contains(c.kind)).length,
      nested: children.where((c) => !memberKinds.contains(c.kind)).length,
      links: [
        for (final kind in LinkKind.values)
          if (outgoing.containsKey(kind) || incoming.containsKey(kind))
            LinkKindStats(
              kind: kind,
              outgoing: outgoing[kind] ?? const ResolutionCounts(),
              incoming: incoming[kind] ?? const ResolutionCounts(),
            ),
      ],
      filePath: node.location?.filePath,
      startLine: node.location?.startLine,
      endLine: node.location?.endLine,
      packageName: node.packageName,
    );
  }

  /// The node's id.
  final String id;

  /// Its name.
  final String name;

  /// Its qualified name.
  final String qualifiedName;

  /// What it is.
  final CodeNodeKind kind;

  /// Lines of code.
  final int loc;

  /// Methods, constructors, getters and setters inside it.
  final int members;

  /// Types, extensions and ghost children inside it (nested subclasses).
  final int nested;

  /// Its links by kind, in kind order, with their resolution quality.
  final List<LinkKindStats> links;

  /// The declaring file.
  final String? filePath;

  /// First line in [filePath].
  final int? startLine;

  /// Last line in [filePath].
  final int? endLine;

  /// The package of a ghost parent or an external package.
  final String? packageName;

  /// Whether the camera can fly into it: it holds something, and it is not
  /// an external package (those are solid).
  bool get isEnterable =>
      (members > 0 || nested > 0) && kind != CodeNodeKind.externalPackage;

  /// `file:start–end`, or null for a node without a location.
  String? get location {
    final path = filePath;
    if (path == null) return null;
    final start = startLine;
    final end = endLine;
    if (start == null) return path;
    return end == null || end == start ? '$path:$start' : '$path:$start–$end';
  }

  /// What "Copy path" copies: the location, or the qualified name.
  String get copyablePath => location ?? qualifiedName;

  @override
  List<Object?> get props => [
    id,
    name,
    qualifiedName,
    kind,
    loc,
    members,
    nested,
    links,
    filePath,
    startLine,
    endLine,
    packageName,
  ];
}
