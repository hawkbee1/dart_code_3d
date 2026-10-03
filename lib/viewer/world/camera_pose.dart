import 'dart:math' as math;

import 'package:code_graph/code_graph.dart';
import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart';

/// Where the camera is and what it looks at.
class CameraPose extends Equatable {
  /// Creates a pose.
  const new({required this.position, required this.target});

  /// The eye position.
  final Vector3 position;

  /// The point looked at.
  final Vector3 target;

  @override
  List<Object?> get props => [position, target];
}

/// The smallest radius used to frame the entry node, so a tiny `main()`
/// sphere is not viewed from a few centimetres away.
const double minimumFramingRadius = 1.5;

/// The start pose: in front of and slightly above the entry node,
/// `entry + (0, r, 3r)`, looking at it. Without an entry node (or when it
/// has no position), the camera frames the world origin the same way.
CameraPose computeStartPose(CodeMap map, Map<String, Vector3> positions) {
  final entryId = map.graph.project.entryNodeId;
  final center = positions[entryId];
  final radius = math.max(
    map.placements[entryId]?.radius ?? 0,
    minimumFramingRadius,
  );
  final target = center ?? Vector3.zero();
  return CameraPose(
    position: target + Vector3(0, radius, 3 * radius),
    target: target,
  );
}

/// The default vertical field of view (flutter_scene's default).
const double defaultFovY = 45 * degrees2Radians;

/// The narrowest horizontal field of view allowed, so a portrait phone does
/// not crop the scene left and right.
const double minimumFovX = 60 * degrees2Radians;

/// The vertical field of view for a view of width / height [aspect]:
/// [defaultFovY] when wide enough, otherwise widened so the horizontal field
/// of view stays at least [minimumFovX].
double fovYForAspect(double aspect) {
  if (aspect <= 0) return defaultFovY;
  final fovYForMinimumX = 2 * math.atan(math.tan(minimumFovX / 2) / aspect);
  return math.max(defaultFovY, fovYForMinimumX);
}
