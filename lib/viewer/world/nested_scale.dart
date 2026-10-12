import 'package:code_graph/code_graph.dart';

/// The share of the size a sphere is laid out at that it is drawn at, for
/// each level it is nested below the top level: spheres inside a sphere were
/// too big to fly between.
const double nestedScale = 0.5;

/// [map] with every level of nesting [factor] times smaller than the one
/// above it: top-level spheres are as laid out, what they contain is
/// [factor] of its laid-out size, what that contains [factor] of that, and so
/// on. Each container keeps its own size, so it just gets more room inside.
///
/// A sphere's offset from its parent is scaled with the parent, so the
/// children keep their places in it: they only shrink around them.
CodeMap scaleNested(CodeMap map, {double factor = nestedScale}) {
  if (factor == 1) return map;
  final scales = <String, double>{};
  // How much smaller than laid out [id] and what it holds are drawn.
  double scaleOf(String id) {
    final known = scales[id];
    if (known != null) return known;
    final parent = map.graph.nodes[id]!.parentId;
    return scales[id] = parent == null ? 1 : factor * scaleOf(parent);
  }

  return CodeMap(
    graph: map.graph,
    placements: {
      for (final MapEntry(key: id, value: placement) in map.placements.entries)
        id: _scaled(placement, map.graph.nodes[id]!.parentId, scaleOf, id),
    },
  );
}

Placement _scaled(
  Placement placement,
  String? parentId,
  double Function(String id) scaleOf,
  String id,
) {
  // Positions are relative to the parent, which is drawn at its own scale.
  final offset = parentId == null ? 1.0 : scaleOf(parentId);
  final own = scaleOf(id);
  return Placement(
    x: placement.x * offset,
    y: placement.y * offset,
    z: placement.z * offset,
    radius: placement.radius * own,
  );
}
