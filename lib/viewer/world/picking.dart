import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// A sphere that can be picked.
typedef Pickable = ({String id, Vector3 center, double radius});

/// The id of the nearest sphere of [spheres] that [ray] hits, or null.
///
/// A sphere the ray starts inside is not hit: the camera is in it, so it
/// is not something to point at. Spheres behind the ray are ignored.
String? pickSphere(Ray ray, Iterable<Pickable> spheres) {
  String? nearest;
  var nearestDistance = double.infinity;
  for (final (:id, :center, :radius) in spheres) {
    final toOrigin = ray.origin - center;
    final c = toOrigin.length2 - radius * radius;
    if (c <= 0) continue;
    final b = toOrigin.dot(ray.direction);
    final discriminant = b * b - c;
    if (discriminant < 0) continue;
    final distance = -b - math.sqrt(discriminant);
    if (distance < 0 || distance >= nearestDistance) continue;
    nearest = id;
    nearestDistance = distance;
  }
  return nearest;
}
