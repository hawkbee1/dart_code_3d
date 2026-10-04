import 'dart:math' as math;

import 'package:dart_code_3d/viewer/navigation/collisions.dart';
import 'package:dart_code_3d/viewer/navigation/containers.dart';
import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:vector_math/vector_math.dart';

/// How far inside a container's shell the camera lands, as a share of the
/// container's radius.
const double insideShellShare = 0.94;

/// How far outside a sphere the camera lands, as a share of its radius.
const double outsideShellShare = 2.2;

/// `count` directions spread evenly on the unit sphere (Fibonacci lattice).
List<Vector3> fibonacciDirections(int count) {
  final golden = math.pi * (3 - math.sqrt(5));
  return [
    for (var i = 0; i < count; i++)
      () {
        final y = 1 - 2 * (i + 0.5) / count;
        final r = math.sqrt(1 - y * y);
        return Vector3(math.cos(golden * i) * r, y, math.sin(golden * i) * r);
      }(),
  ];
}

/// Where the camera should land to be in [target] (a container, or the
/// world when null), coming from [from] in [current].
///
/// - A container: just inside its shell, looking at its center.
/// - The world: just outside the top-level sphere that holds [current],
///   looking at it.
///
/// The landing spot is chosen on the side of the camera when it fits, and
/// otherwise on the first direction of a Fibonacci lattice from which the
/// camera really is in [target] (not inside a child sphere, a neighbour or
/// a solid package).
CameraPose exitPose({
  required CodeWorld world,
  required String? target,
  required Vector3 from,
  required String? current,
}) {
  final String? focus;
  if (target != null) {
    focus = target;
  } else if (current != null) {
    focus = world.index.chainOf(current).last;
  } else {
    return world.startPose;
  }
  final center = world.positions[focus]!;
  final radius = world.map.placements[focus]!.radius;
  final distance =
      radius * (target != null ? insideShellShare : outsideShellShare);
  final side = from - center;
  final candidates = [
    if (side.length > 1e-6) side.normalized(),
    ...fibonacciDirections(32),
  ];
  Vector3 position(Vector3 direction) => center + direction * distance;
  bool fits(Vector3 point) =>
      findContainer(point, world.map, world.positions) == target &&
      resolveCollisions(point, world.obstacles).distanceTo(point) < 1e-9;
  final chosen = candidates.firstWhere(
    (direction) => fits(position(direction)),
    orElse: () => candidates.first,
  );
  return CameraPose(position: position(chosen), target: center);
}
