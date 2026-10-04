import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:vector_math/vector_math.dart';

/// Depth (along the view direction) under which nothing is projected: the
/// camera's near plane.
const double nearDepth = 0.05;

/// The camera as the renderer sees it: where it is, where it looks, how wide
/// it sees, and the size of the view. It converts between world points and
/// screen positions, so labels, picking and the minimap agree with what is
/// drawn.
///
/// Right-handed with +Y up, like flutter_scene's `PerspectiveCamera`: the
/// right of the view is `forward × up`, and the field of view is vertical.
class ViewCamera {
  /// Creates a camera at [position] looking along [forward] (any length),
  /// with a vertical field of view [fovY] (radians), for a view of [size].
  new({
    required Vector3 position,
    required Vector3 forward,
    required this.fovY,
    required this.size,
  }) : position = position.clone(),
       forward = forward.normalized() {
    final cross = this.forward.cross(Vector3(0, 1, 0));
    // Looking straight up or down has no "right": use +X.
    right = cross.length2 < 1e-12 ? Vector3(1, 0, 0) : cross.normalized();
    up = right.cross(this.forward);
  }

  /// A camera at [pose] with the field of view the viewer uses for [size]
  /// (`fovYForAspect`), looking at the pose's target.
  factory fromPose(CameraPose pose, Size size, {required double fovY}) =>
      ViewCamera(
        position: pose.position,
        forward: pose.target - pose.position,
        fovY: fovY,
        size: size,
      );

  /// The eye.
  final Vector3 position;

  /// The unit look direction.
  final Vector3 forward;

  /// Vertical field of view, in radians.
  final double fovY;

  /// The view's size, in logical pixels.
  final Size size;

  /// The unit vector pointing to the right of the view.
  late final Vector3 right;

  /// The unit vector pointing to the top of the view.
  late final Vector3 up;

  double get _tanHalf => math.tan(fovY / 2);

  double get _aspect => size.height == 0 ? 1 : size.width / size.height;

  /// How far [point] is in front of the camera (negative when behind).
  double depthOf(Vector3 point) => (point - position).dot(forward);

  /// Where [point] is on the screen, or null when it is behind the camera
  /// (or closer than [nearDepth]). The result can be outside the view.
  Offset? project(Vector3 point) {
    final offset = point - position;
    final depth = offset.dot(forward);
    if (depth <= nearDepth) return null;
    final x = offset.dot(right) / (depth * _tanHalf * _aspect);
    final y = offset.dot(up) / (depth * _tanHalf);
    return Offset((x + 1) / 2 * size.width, (1 - y) / 2 * size.height);
  }

  /// The radius, in pixels, of a sphere of [radius] whose center is at
  /// [center] (infinite when its center is not in front of the camera).
  double screenRadius(Vector3 center, double radius) {
    final depth = depthOf(center);
    if (depth <= nearDepth) return double.infinity;
    return radius * (size.height / 2) / (depth * _tanHalf);
  }

  /// The ray from the eye through the screen position [screen].
  Ray rayAt(Offset screen) {
    // An empty view has no screen: look straight ahead.
    final x = size.width == 0 ? 0.0 : 2 * screen.dx / size.width - 1;
    final y = size.height == 0 ? 0.0 : 1 - 2 * screen.dy / size.height;
    final direction =
        forward + right * (x * _tanHalf * _aspect) + up * (y * _tanHalf);
    return Ray.originDirection(position, direction.normalized());
  }
}
