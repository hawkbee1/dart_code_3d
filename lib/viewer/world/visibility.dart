import 'package:code_graph/code_graph.dart';
import 'package:equatable/equatable.dart';

/// What the viewer shows, the camera being in a given container.
class VisibleWorld extends Equatable {
  /// Creates a visible world.
  const new({
    required this.openContainers,
    required this.visibleSpheres,
    required this.links,
  });

  /// The spheres around the camera, outermost first (empty at the top
  /// level). The last one is the current container.
  final List<String> openContainers;

  /// The spheres drawn closed (their insides hidden).
  final List<String> visibleSpheres;

  /// The links drawn, between visible spheres.
  final List<VisibleLink> links;

  @override
  List<Object?> get props => [openContainers, visibleSpheres, links];
}

/// A link between two visible spheres, possibly standing for several links
/// whose endpoints are hidden inside them.
class VisibleLink extends Equatable {
  /// Creates a visible link.
  const new({
    required this.fromId,
    required this.toId,
    required this.kind,
    required this.count,
    required this.aggregated,
    this.dim = false,
  });

  /// The visible sphere the link starts from.
  final String fromId;

  /// The visible sphere the link points to.
  final String toId;

  /// The kind of every link merged here.
  final LinkKind kind;

  /// How many links (with their call counts) are merged here.
  final int count;

  /// Whether an endpoint was remapped to a visible ancestor.
  final bool aggregated;

  /// Whether every merged link is uncertain (ambiguous) or leaves the
  /// project (external): drawn dimmer.
  final bool dim;

  @override
  List<Object?> get props => [fromId, toId, kind, count, aggregated, dim];
}

/// Precomputed ancestor chains of a map, so [resolveVisibility] stays fast
/// on large maps (AltMe: 11k nodes, thousands of links).
class VisibilityIndex {
  /// Indexes [map].
  new(this.map) {
    for (final id in map.graph.nodes.keys) {
      _chains[id] = [id, ...map.graph.ancestorsOf(id).map((n) => n.id)];
    }
    final kinds = {for (final link in map.graph.links) link.kind};
    linkKinds = [
      for (final kind in LinkKind.values)
        if (kinds.contains(kind)) kind,
    ];
  }

  /// The index of [map], built once and shared (by the viewer state and the
  /// 3D world).
  factory of(CodeMap map) => _indexes[map] ??= VisibilityIndex(map);

  static final _indexes = Expando<VisibilityIndex>('visibility index');

  /// The indexed map.
  final CodeMap map;

  /// The link kinds the map has at least one link of, in enum order.
  late final List<LinkKind> linkKinds;

  // Node first, then its ancestors, nearest first.
  final _chains = <String, List<String>>{};

  /// [id] then its ancestors, nearest first.
  List<String> chainOf(String id) => _chains[id]!;
}

/// What is seen from inside a sphere.
enum ViewMode {
  /// Only the inside of the current sphere.
  interior,

  /// The inside, plus the outer world through a transparent shell.
  window,
}

/// Resolves what is visible with the camera in [containerId] (the top level
/// when null).
///
/// - Interior: the children of the current container. Window: also the
///   children of every open ancestor and the top level. At the top level,
///   the top-level nodes, whatever the mode.
/// - Links of the [linkKinds]: each endpoint is mapped to its nearest
///   visible representative (itself or its closest visible ancestor). Links
///   whose ends map to the same sphere, or to nothing visible, are dropped;
///   duplicates are merged by summing counts. With [selectedId], only the
///   links touching the selected node's representative are kept.
VisibleWorld resolveVisibility({
  required VisibilityIndex index,
  required String? containerId,
  required ViewMode mode,
  required Set<LinkKind> linkKinds,
  String? selectedId,
}) {
  final graph = index.map.graph;
  final open = containerId == null
      ? const <String>[]
      : index.chainOf(containerId).reversed.toList();
  final openSet = open.toSet();
  final visible = <String>[
    if (containerId != null && mode == ViewMode.window) ...[
      for (final node in graph.topLevel)
        if (!openSet.contains(node.id)) node.id,
      for (final ancestor in open.take(open.length - 1))
        for (final node in graph.childrenOf(ancestor))
          if (!openSet.contains(node.id)) node.id,
    ],
    for (final node in graph.childrenOf(containerId)) node.id,
  ];
  final visibleSet = visible.toSet();

  String? representative(String id) {
    for (final candidate in index.chainOf(id)) {
      if (visibleSet.contains(candidate)) return candidate;
    }
    return null;
  }

  final focus = selectedId == null ? null : representative(selectedId);
  final merged = <(String, String, LinkKind), _Merge>{};
  for (final link in graph.links) {
    if (!linkKinds.contains(link.kind)) continue;
    final from = representative(link.fromId);
    final to = representative(link.toId);
    if (from == null || to == null || from == to) continue;
    if (focus != null && from != focus && to != focus) continue;
    final dim =
        link.resolution == LinkResolution.ambiguous ||
        link.resolution == LinkResolution.external;
    (merged[(from, to, link.kind)] ??= _Merge()).add(
      link.count,
      aggregated: from != link.fromId || to != link.toId,
      dim: dim,
    );
  }
  return VisibleWorld(
    openContainers: open,
    visibleSpheres: visible,
    links: [
      for (final MapEntry(key: (from, to, kind), value: m) in merged.entries)
        VisibleLink(
          fromId: from,
          toId: to,
          kind: kind,
          count: m.count,
          aggregated: m.aggregated,
          dim: m.dim,
        ),
    ],
  );
}

class _Merge {
  int count = 0;
  bool aggregated = false;
  bool dim = true;

  void add(int linkCount, {required bool aggregated, required bool dim}) {
    count += linkCount;
    this.aggregated |= aggregated;
    this.dim &= dim;
  }
}
