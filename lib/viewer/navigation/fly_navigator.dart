import 'dart:math' as math;

import 'package:dart_code_3d/viewer/navigation/collisions.dart';
import 'package:dart_code_3d/viewer/navigation/containers.dart';
import 'package:dart_code_3d/viewer/navigation/fly_plan.dart';
import 'package:dart_code_3d/viewer/world/camera_pose.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:dart_code_3d/viewer/world/view_camera.dart';
import 'package:flutter/foundation.dart';
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

  /// Whether the user is pressing or touching anything.
  bool get active =>
      forward ||
      back ||
      left ||
      right ||
      up ||
      down ||
      throttle != 0 ||
      lookRate != Offset.zero;

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
///
/// It notifies its listeners whenever the camera has moved or turned, so
/// overlays (labels, minimap) redraw only when needed.
class FlyNavigator extends ChangeNotifier {
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
  _Flight? _flight;
  Vector3? _notifiedPosition;
  Vector3? _notifiedForward;

  /// The sphere the camera is in (the world when null).
  String? get container => _container;

  /// Whether the camera is on an automatic flight ([flyTo]).
  bool get isFlying => _flight != null;

  /// The eye position.
  Vector3 get position => _flight?.position ?? _controller.position;

  /// The unit look direction.
  Vector3 get forward => _flight?.forward ?? _controller.forward;

  /// The current pose.
  CameraPose get pose =>
      CameraPose(position: position, target: position + forward);

  /// A camera at the current pose for a view of [size].
  PerspectiveCamera camera(Size size) => world.camera(size, pose: pose);

  /// The same camera as a [ViewCamera], to project world points onto the
  /// screen and to cast rays through it.
  ViewCamera viewCamera(Size size) =>
      ViewCamera.fromPose(pose, size, fovY: world.fovYFor(size));

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

  /// Flies the camera to [destination] over [duration] seconds, or jumps
  /// there without [animate]. Touching any control takes the camera back.
  void flyTo(
    CameraPose destination, {
    double duration = 1,
    bool animate = true,
  }) => _fly([destination], duration: duration, animate: animate);

  /// Flies the camera through [destinations] in turn, smoothly (it does not
  /// stop at each one), in a time that grows with the distance: 0.6 s to
  /// 1.5 s. The container the camera is in is reported when it passes each
  /// destination, not for every sphere it crosses on the way.
  void flyAlong(List<CameraPose> destinations, {bool animate = true}) {
    var length = 0.0;
    var from = position;
    for (final destination in destinations) {
      length += from.distanceTo(destination.position);
      from = destination.position;
    }
    _fly(
      destinations,
      duration: flightDuration(length, world.radius),
      animate: animate,
    );
  }

  void _fly(
    List<CameraPose> destinations, {
    required double duration,
    required bool animate,
  }) {
    if (!animate || duration <= 0) {
      _jumpTo(destinations.last);
      _trackContainer();
      _notifyIfMoved();
      return;
    }
    _flight = _Flight(poses: [pose, ...destinations], duration: duration);
  }

  /// Advances the flight by [deltaSeconds].
  void step(double deltaSeconds) {
    final flight = _flight;
    if (flight != null) {
      if (input.active) {
        _jumpTo(pose);
      } else {
        for (final reached in flight.advance(deltaSeconds, world.obstacles)) {
          if (reached != flight.poses.length - 1) {
            _trackContainerAt(flight.poses[reached].position);
          }
        }
        if (flight.done) {
          _jumpTo(flight.poses.last);
          _trackContainer();
        }
        _notifyIfMoved();
        return;
      }
    }
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
    _trackContainer();
    _notifyIfMoved();
  }

  /// Returns to the start pose and releases every input.
  void reset() {
    input.clear();
    _jumpTo(start);
    _container = findContainer(position, world.map, world.positions);
    _notifyIfMoved();
  }

  /// Puts the camera at [destination] (pushed out of solid spheres).
  void _jumpTo(CameraPose destination) {
    final position = resolveCollisions(destination.position, world.obstacles);
    _flight = null;
    _heldKeys.clear();
    _controller = _controllerAt(
      CameraPose(
        position: position,
        target: destination.target + (position - destination.position),
      ),
      baseSpeed,
    );
    _attach();
  }

  void _trackContainer() => _trackContainerAt(position);

  void _trackContainerAt(Vector3 point) {
    final container = findContainer(point, world.map, world.positions);
    if (container != _container) {
      _container = container;
      onContainerChanged?.call(container);
    }
  }

  void _notifyIfMoved() {
    final here = position;
    final looking = forward;
    final lastPosition = _notifiedPosition;
    final lastForward = _notifiedForward;
    if (lastPosition != null &&
        lastForward != null &&
        here.distanceToSquared(lastPosition) < 1e-12 &&
        looking.distanceToSquared(lastForward) < 1e-12) {
      return;
    }
    _notifiedPosition = here;
    _notifiedForward = looking;
    notifyListeners();
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

/// An automatic flight through a list of poses: one smooth start and stop
/// along the whole path (not at each pose), the camera pushed out of solid
/// spheres on the way.
class _Flight {
  new({required this.poses, required this.duration}) {
    // The distance along the path at each pose. A path with no length at
    // all (every pose in the same place) is made of unit steps.
    var along = 0.0;
    final lengths = <double>[0];
    for (var i = 1; i < poses.length; i++) {
      along += poses[i].position.distanceTo(poses[i - 1].position);
      lengths.add(along);
    }
    if (along < 1e-9) {
      for (var i = 0; i < lengths.length; i++) {
        lengths[i] = i.toDouble();
      }
      along = (poses.length - 1).toDouble();
    }
    _distances = lengths;
    _length = along;
    position = poses.first.position.clone();
    forward = _direction(poses.first);
  }

  final List<CameraPose> poses;
  final double duration;

  late final List<double> _distances;
  late final double _length;
  double _elapsed = 0;
  int _reached = 0;

  Vector3 position = Vector3.zero();
  Vector3 forward = Vector3(0, 0, -1);

  bool get done => _elapsed >= duration;

  static Vector3 _direction(CameraPose pose) =>
      (pose.target - pose.position).normalized();

  /// Moves along the path and returns the poses it has reached since the
  /// last call (by index, in order).
  List<int> advance(double deltaSeconds, List<Obstacle> obstacles) {
    _elapsed += deltaSeconds;
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final along = t * t * (3 - 2 * t) * _length;

    var segment = 0;
    while (segment < poses.length - 2 && along > _distances[segment + 1]) {
      segment++;
    }
    final from = poses[segment];
    final to = poses[segment + 1];
    final span = _distances[segment + 1] - _distances[segment];
    final u = span <= 0
        ? 1.0
        : ((along - _distances[segment]) / span).clamp(0.0, 1.0);
    position = resolveCollisions(
      from.position + (to.position - from.position) * u,
      obstacles,
    );
    final finish = _direction(to);
    final blended = _direction(from) * (1 - u) + finish * u;
    forward = blended.length2 < 1e-12 ? finish : blended.normalized();

    final reached = <int>[];
    while (_reached < poses.length - 1 &&
        along >= _distances[_reached + 1] - 1e-9) {
      _reached++;
      reached.add(_reached);
    }
    return reached;
  }
}
