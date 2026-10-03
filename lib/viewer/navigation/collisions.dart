import 'package:vector_math/vector_math.dart';

/// A solid sphere the camera cannot enter.
typedef Obstacle = ({Vector3 center, double radius});

/// How far from an obstacle's surface the camera stops.
const double collisionMargin = 0.25;

/// [position] pushed out of every obstacle, to `radius + margin` from its
/// center. A few passes settle positions between touching obstacles.
Vector3 resolveCollisions(
  Vector3 position,
  List<Obstacle> obstacles, {
  double margin = collisionMargin,
}) {
  final resolved = position.clone();
  for (var pass = 0; pass < 4; pass++) {
    var moved = false;
    for (final (:center, :radius) in obstacles) {
      final minimum = radius + margin;
      final offset = resolved - center;
      final distance = offset.length;
      if (distance >= minimum) continue;
      // From the exact center, leave towards +Z (towards the default eye).
      final direction = distance == 0
          ? Vector3(0, 0, 1)
          : (offset..normalize());
      resolved.setFrom(center + direction * minimum);
      moved = true;
    }
    if (!moved) break;
  }
  return resolved;
}
