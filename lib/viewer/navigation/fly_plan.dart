import 'package:dart_code_3d/viewer/navigation/collisions.dart';
import 'package:dart_code_3d/viewer/navigation/containers.dart';
import 'package:dart_code_3d/viewer/navigation/exit_pose.dart';
import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:vector_math/vector_math.dart';

/// How many radii from a node the camera stands to face it, from the
/// preferred distance to the closest one used in a cramped container.
const List<double> facingDistances = [4, 3, 2, 1.4];

/// Where the camera should be to look at node [target] from outside it: in
/// the container that holds the node, at about four radii (closer when the
/// container is cramped), on the side of [from] when that is free and
/// otherwise on the first direction of a Fibonacci lattice that is.
CameraPose facingPose({
  required CodeWorld world,
  required String target,
  required Vector3 from,
}) {
  final center = world.positions[target]!;
  final radius = world.map.placements[target]!.radius;
  final parent = world.map.graph.nodes[target]!.parentId;
  final side = from - center;
  final directions = [
    if (side.length > 1e-6) side.normalized(),
    ...fibonacciDirections(32),
  ];
  bool fits(Vector3 point) =>
      findContainer(point, world.map, world.positions) == parent &&
      resolveCollisions(point, world.obstacles).distanceTo(point) < 1e-9;
  for (final factor in facingDistances) {
    for (final direction in directions) {
      final position = center + direction * (radius * factor);
      if (fits(position)) {
        return CameraPose(position: position, target: center);
      }
    }
  }
  return CameraPose(
    position: center + directions.first * (radius * facingDistances.first),
    target: center,
  );
}

/// The poses to fly through to reach node [target] from [from] (in container
/// [current], the world when null), following the containment: leave the
/// containers that do not hold the target, enter the ones that do, then face
/// the target.
///
/// Leaving lands just inside the shell of the nearest container that holds
/// both (or outside the top-level sphere when there is none); each container
/// to enter is landed in just inside its shell; the last pose faces the
/// target. A target next to the camera needs only the last pose.
List<CameraPose> flyToNodePlan({
  required CodeWorld world,
  required Vector3 from,
  required String? current,
  required String target,
}) {
  final index = world.index;
  final inside = current == null
      ? const <String>[]
      : index.chainOf(current).reversed.toList();
  final holders = index.chainOf(target).skip(1).toList().reversed.toList();
  var shared = 0;
  while (shared < inside.length &&
      shared < holders.length &&
      inside[shared] == holders[shared]) {
    shared++;
  }

  final poses = <CameraPose>[];
  var side = from;
  if (inside.length > shared) {
    poses.add(
      exitPose(
        world: world,
        target: shared == 0 ? null : inside[shared - 1],
        from: side,
        current: current,
      ),
    );
    side = poses.last.position;
  }
  for (final holder in holders.skip(shared)) {
    poses.add(
      exitPose(world: world, target: holder, from: side, current: null),
    );
    side = poses.last.position;
  }
  poses.add(facingPose(world: world, target: target, from: side));
  return poses;
}

/// How long to take to fly [length] world units in a world of
/// [worldRadius]: from 0.6 s for a hop to 1.5 s across the whole world.
double flightDuration(double length, double worldRadius) {
  final share = worldRadius <= 0 ? 1.0 : length / (2 * worldRadius);
  return (0.6 + 0.9 * share).clamp(0.6, 1.5);
}
