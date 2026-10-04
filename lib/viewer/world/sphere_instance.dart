import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:material_ui/material_ui.dart' show Color;
import 'package:vector_math/vector_math.dart';

/// One sphere to draw: a node at a world [center] with a [radius] and a
/// linear RGBA [color].
class SphereInstance extends Equatable {
  /// Creates an instance.
  const new({
    required this.nodeId,
    required this.center,
    required this.radius,
    required this.color,
  });

  /// The node drawn.
  final String nodeId;

  /// World-space center.
  final Vector3 center;

  /// Radius in world units.
  final double radius;

  /// Linear RGBA color multiplier.
  final Vector4 color;

  /// The model transform: a unit sphere scaled to [radius] at [center].
  Matrix4 get transform =>
      Matrix4.compose(center, Quaternion.identity(), Vector3.all(radius));

  @override
  List<Object?> get props => [nodeId, center, radius, color];
}

/// [color] (sRGB) as a linear RGBA vector, what the renderer multiplies.
Vector4 linearColor(Color color) {
  double linear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return Vector4(linear(color.r), linear(color.g), linear(color.b), color.a);
}
