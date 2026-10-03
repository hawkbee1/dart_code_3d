import 'package:code_graph/code_graph.dart';
import 'package:vector_math/vector_math.dart';

/// The deepest enterable sphere of [map] that contains [point], or null for
/// the world. External package spheres are solid, so never containers.
String? findContainer(
  Vector3 point,
  CodeMap map,
  Map<String, Vector3> positions,
) {
  String? container;
  while (true) {
    String? inside;
    for (final node in map.graph.childrenOf(container)) {
      if (node.kind == CodeNodeKind.externalPackage) continue;
      final radius = map.placements[node.id]!.radius;
      if (positions[node.id]!.distanceTo(point) < radius) {
        inside = node.id;
        break;
      }
    }
    if (inside == null) return container;
    container = inside;
  }
}
