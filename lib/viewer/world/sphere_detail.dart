import 'package:dart_code_3d/viewer/world/sphere_instance.dart';
import 'package:vector_math/vector_math.dart';

/// How finely a sphere is drawn, by how large it looks.
///
/// A sphere that fills the screen needs a round silhouette, one a few pixels
/// wide does not: drawing every one of thousands of spheres at full detail
/// made the frame rate triangle-bound on big maps (about 2,300 triangles each
/// at 48×24, 144 at 12×6).
enum SphereDetail {
  /// Spheres about 20 pixels across or less.
  low(segments: 12, rings: 6),

  /// Spheres from about 20 to 80 pixels across.
  medium(segments: 24, rings: 12),

  /// Larger spheres, and the one the camera is inside or touching.
  high(segments: 48, rings: 24);

  new({required this.segments, required this.rings});

  /// Slices around the sphere.
  final int segments;

  /// Bands from pole to pole.
  final int rings;

  /// The detail of a sphere of [radius] seen from [distance] (to its center).
  ///
  /// It goes by the share of the view the sphere takes, `radius / distance`;
  /// [mediumShare] and [highShare] are about 20 and 80 pixels across on a
  /// 900 px high view with a 60° field of view (narrower screens see the
  /// same sphere smaller, so they get more detail than they need, never less).
  static SphereDetail of({
    required double radius,
    required double distance,
    double mediumShare = 0.012,
    double highShare = 0.05,
  }) {
    if (distance <= radius) return high;
    final share = radius / distance;
    if (share >= highShare) return high;
    return share >= mediumShare ? medium : low;
  }

  /// The detail of each of [spheres] seen from [camera].
  static List<SphereDetail> allOf(
    List<SphereInstance> spheres,
    Vector3 camera,
  ) => [
    for (final sphere in spheres)
      of(radius: sphere.radius, distance: sphere.center.distanceTo(camera)),
  ];
}
