import 'package:code_graph/code_graph.dart';
import 'package:vector_math/vector_math.dart';

/// World-space centers of every node of [map]: placements are relative to
/// the parent's center, so each center is the sum along the ancestor chain.
Map<String, Vector3> worldPositions(CodeMap map) {
  final positions = <String, Vector3>{};
  Vector3 positionOf(String id) {
    final known = positions[id];
    if (known != null) return known;
    final local = map.placements[id]!.position;
    final parentId = map.graph.nodes[id]!.parentId;
    return positions[id] = parentId == null
        ? local
        : positionOf(parentId) + local;
  }

  map.graph.nodes.keys.forEach(positionOf);
  return positions;
}

/// The radius of the smallest sphere around the origin that holds every
/// top-level sphere of [map] (at least 1).
double worldRadius(CodeMap map) {
  var radius = 1.0;
  for (final node in map.graph.topLevel) {
    final p = map.placements[node.id]!;
    final extent = p.position.length + p.radius;
    if (extent > radius) radius = extent;
  }
  return radius;
}
