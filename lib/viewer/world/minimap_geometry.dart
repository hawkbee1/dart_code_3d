import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math.dart';

/// A sphere on the minimap.
typedef MinimapSphere = ({String id, Vector3 center, double radius});

/// A top-down view of a set of spheres fitted into a square of [size]:
/// the world's X goes right and its Z goes down, so "north" (-Z) is up.
class MinimapProjection {
  /// Fits [spheres] (their centers and radii) into [size], with [padding]
  /// around them.
  factory fit(
    Iterable<MinimapSphere> spheres,
    Size size, {
    double padding = 8,
  }) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minZ = double.infinity;
    var maxZ = double.negativeInfinity;
    for (final (id: _, :center, :radius) in spheres) {
      minX = math.min(minX, center.x - radius);
      maxX = math.max(maxX, center.x + radius);
      minZ = math.min(minZ, center.z - radius);
      maxZ = math.max(maxZ, center.z + radius);
    }
    if (minX > maxX) {
      // Nothing to show: a unit world around the origin.
      minX = minZ = -1;
      maxX = maxZ = 1;
    }
    final spanX = math.max(maxX - minX, 1e-6);
    final spanZ = math.max(maxZ - minZ, 1e-6);
    final scale = math.min(
      (size.width - 2 * padding) / spanX,
      (size.height - 2 * padding) / spanZ,
    );
    return MinimapProjection._(
      scale: scale > 0 ? scale : 1,
      centerX: (minX + maxX) / 2,
      centerZ: (minZ + maxZ) / 2,
      size: size,
    );
  }

  const new _({
    required this.scale,
    required this.centerX,
    required this.centerZ,
    required this.size,
  });

  /// Pixels per world unit.
  final double scale;

  /// The world X shown in the middle.
  final double centerX;

  /// The world Z shown in the middle.
  final double centerZ;

  /// The size of the minimap.
  final Size size;

  /// Where [point] is on the minimap (it can be outside it).
  Offset toMap(Vector3 point) => Offset(
    size.width / 2 + (point.x - centerX) * scale,
    size.height / 2 + (point.z - centerZ) * scale,
  );

  /// [point] on the minimap, kept inside it (inset by [margin]).
  Offset toMapClamped(Vector3 point, {double margin = 4}) {
    final at = toMap(point);
    return Offset(
      at.dx.clamp(margin, math.max(margin, size.width - margin)),
      at.dy.clamp(margin, math.max(margin, size.height - margin)),
    );
  }

  /// A world length in pixels.
  double lengthToMap(double length) => length * scale;

  /// Where [sphere] is drawn and how big: its own circle (at least
  /// [minRadius] wide), or, when its center is off the map, a dot of
  /// [pinnedRadius] pinned to the edge on the side it lies.
  ({Offset at, double radius}) place(
    MinimapSphere sphere, {
    double margin = 4,
    double minRadius = 2,
    double pinnedRadius = 3,
  }) {
    final at = toMap(sphere.center);
    final onMap =
        at.dx >= margin &&
        at.dx <= size.width - margin &&
        at.dy >= margin &&
        at.dy <= size.height - margin;
    return onMap
        ? (at: at, radius: math.max(lengthToMap(sphere.radius), minRadius))
        : (
            at: toMapClamped(sphere.center, margin: margin),
            radius: pinnedRadius,
          );
  }
}

/// The sphere under [tap] on the minimap, where [MinimapProjection.place]
/// puts it: among the circles that contain it (or are within [slop] pixels,
/// so small spheres can be hit), the smallest, since a top-down view stacks
/// spheres on top of each other.
String? minimapHit(
  Offset tap,
  Iterable<MinimapSphere> spheres,
  MinimapProjection projection, {
  double slop = 8,
}) {
  String? best;
  var bestRadius = double.infinity;
  for (final sphere in spheres) {
    final placed = projection.place(sphere);
    if ((placed.at - tap).distance > math.max(placed.radius, slop)) continue;
    if (sphere.radius < bestRadius) {
      best = sphere.id;
      bestRadius = sphere.radius;
    }
  }
  return best;
}
