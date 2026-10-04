import 'dart:math' as math;

import 'package:dart_code_3d/viewer/navigation/collisions.dart';
import 'package:dart_code_3d/viewer/navigation/containers.dart';
import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// What the user is pressing: keyboard keys, touch controls or both.
class NavigationInput {
  /// Fly along the look direction.
  bool forward = false;

  /// Fly backwards.
  bool back = false;

  /// Strafe left.
  bool left = false;

  /// Strafe right.
  bool right = false;

  /// Fly up.
  bool up = false;

  /// Fly down.
  bool down = false;

  /// Fly faster.
  bool boost = false;

  /// Forward (positive) or backward (negative) speed from the touch slider,
  /// -1 to 1. When not 0 it replaces [forward] and [back].
  double throttle = 0;

  /// Continuous look, in logical pixels per second (the trackball).
  Offset lookRate = Offset.zero;

  /// Releases everything.
  void clear() {
    forward = back = left = right = up = down = boost = false;
    throttle = 0;
    lookRate = Offset.zero;
  }
}

/// Flies the camera through a [CodeWorld].
///
/// Wraps flutter_scene's [FlyCameraController]: our inputs are mapped onto
/// its move keys, and it is stepped manually ([step]), so a fixed time step
/// gives a reproducible flight. After each step the camera is pushed out of
/// external package spheres (the only solid ones) and the sphere it is in
/// is detected.
class FlyNavigator {
  /// Creates a navigator at [start] ([world]'s start pose by default).
  /// [onContainerChanged] is called when the camera enters or leaves a
  /// sphere.
  new({
    required this.world,
    CameraPose? start,
    this.baseSpeed = 2.5,
    this.onContainerChanged,
  }) : start = start ?? world.startPose,
       _controller = _controllerAt(start ?? world.startPose, baseSpeed) {
    _attach();
    _container = findContainer(position, world.map, world.positions);
  }

  /// The world flown through.
  final CodeWorld world;

  /// Where the flight starts, and where [reset] returns.
  final CameraPose start;

  /// Speed, in world units per second, in a sphere of radius 10: crossing
  /// any sphere takes about 8 seconds.
  final double baseSpeed;

  /// Called with the new container when the camera enters or leaves one.
  final void Function(String? containerId)? onContainerChanged;

  /// What the user is pressing.
  final input = NavigationInput();

  FlyCameraController _controller;
  final _heldKeys = <LogicalKeyboardKey>{};
  String? _container;

  /// The sphere the camera is in (the world when null).
  String? get container => _container;

  /// The eye position.
  Vector3 get position => _controller.position;

  /// The unit look direction.
  Vector3 get forward => _controller.forward;

  /// The current pose.
  CameraPose get pose =>
      CameraPose(position: position, target: position + forward);

  /// A camera at the current pose for a view of [size].
  PerspectiveCamera camera(Size size) => world.camera(size, pose: pose);

  /// The speed for the current container: [baseSpeed] scaled by its radius
  /// (the world's at the top level), so a tiny class and the whole world
  /// are both comfortable to fly through.
  double get speed {
    final container = _container;
    final radius = container == null
        ? world.radius
        : world.map.placements[container]!.radius;
    return baseSpeed * (radius / 10).clamp(0.05, 50);
  }

  /// Turns the view by a drag of [delta] logical pixels.
  void look(Offset delta) => _controller.look(delta);

  /// Advances the flight by [deltaSeconds].
  void step(double deltaSeconds) {
    final throttle = input.throttle.clamp(-1.0, 1.0);
    _hold({
      if (throttle > 0 || (throttle == 0 && input.forward))
        LogicalKeyboardKey.keyW,
      if (throttle < 0 || (throttle == 0 && input.back))
        LogicalKeyboardKey.keyS,
      if (input.left) LogicalKeyboardKey.keyA,
      if (input.right) LogicalKeyboardKey.keyD,
      if (input.up) LogicalKeyboardKey.keyE,
      if (input.down) LogicalKeyboardKey.keyQ,
      if (input.boost) LogicalKeyboardKey.shiftLeft,
    });
    _controller.speed = speed * (throttle == 0 ? 1 : throttle.abs());
    if (input.lookRate != Offset.zero) look(input.lookRate * deltaSeconds);
    _controller
      ..update(deltaSeconds)
      ..position = resolveCollisions(_controller.position, world.obstacles);
    final container = findContainer(position, world.map, world.positions);
    if (container != _container) {
      _container = container;
      onContainerChanged?.call(container);
    }
  }

  /// Returns to the start pose and releases every input.
  void reset() {
    input.clear();
    _heldKeys.clear();
    _controller = _controllerAt(start, baseSpeed);
    _attach();
    _container = findContainer(position, world.map, world.positions);
  }

  void _attach() => Node(name: 'camera').addComponent(_controller);

  // Mapped onto the controller's own keys: it only takes key events.
  void _hold(Set<LogicalKeyboardKey> keys) {
    for (final key in keys.difference(_heldKeys)) {
      _controller.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: key,
          timeStamp: Duration.zero,
        ),
      );
    }
    for (final key in _heldKeys.difference(keys)) {
      _controller.handleKeyEvent(
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: key,
          timeStamp: Duration.zero,
        ),
      );
    }
    _heldKeys
      ..clear()
      ..addAll(keys);
  }

  static FlyCameraController _controllerAt(CameraPose pose, double speed) {
    final direction = (pose.target - pose.position)..normalize();
    return FlyCameraController(
      position: pose.position,
      // The controller looks along (-sin(yaw)·cos(pitch), sin(pitch),
      // -cos(yaw)·cos(pitch)).
      yaw: math.atan2(-direction.x, -direction.z),
      pitch: math.asin(direction.y.clamp(-1.0, 1.0)),
      speed: speed,
    );
  }
}
