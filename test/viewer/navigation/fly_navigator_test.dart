import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Offset, Size;
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

const double _dt = 1 / 30;

/// Steps [navigator] for [seconds] with a fixed time step.
void _fly(FlyNavigator navigator, double seconds) {
  for (var i = 0; i < (seconds / _dt).round(); i++) {
    navigator.step(_dt);
  }
}

void main() {
  group(FlyNavigator, () {
    late CodeWorld world;

    setUp(() => world = CodeWorld(worldMap(), CodeWorldColors.light));

    // Looking along -X from x = 30 (outside every sphere: world speed).
    FlyNavigator lookingWest({void Function(String?)? onContainerChanged}) =>
        FlyNavigator(
          world: world,
          start: CameraPose(
            position: Vector3(30, 5, 0),
            target: Vector3(0, 5, 0),
          ),
          onContainerChanged: onContainerChanged,
        );

    test('starts at the start pose, looking at the entry node', () {
      final navigator = FlyNavigator(world: world);

      expect(navigator.position, world.startPose.position);
      final expected = (world.startPose.target - world.startPose.position)
        ..normalize();
      expect(navigator.forward.distanceTo(expected), lessThan(1e-6));
      expect(navigator.container, isNull);
      expect(navigator.pose.position, navigator.position);
    });

    test('flies forward along the look direction at the world speed', () {
      final navigator = lookingWest()..input.forward = true;
      final speed = navigator.speed;

      _fly(navigator, 1);

      expect(speed, closeTo(navigator.baseSpeed * world.radius / 10, 1e-9));
      expect(navigator.position.x, closeTo(30 - speed, 1e-3));
      expect(navigator.position.y, closeTo(5, 1e-4));
    });

    test('flies back, strafes, climbs and boosts', () {
      final back = lookingWest()..input.back = true;
      _fly(back, 1);
      expect(back.position.x, greaterThan(30));

      final strafe = lookingWest()..input.right = true;
      _fly(strafe, 1);
      expect(strafe.position.x, closeTo(30, 1e-4));
      expect(strafe.position.z, isNot(closeTo(0, 1e-3)));

      final up = lookingWest()..input.up = true;
      _fly(up, 1);
      expect(up.position.y, greaterThan(5));

      final down = lookingWest()..input.down = true;
      _fly(down, 1);
      expect(down.position.y, lessThan(5));

      final plain = lookingWest()..input.forward = true;
      final boosted = lookingWest()
        ..input.forward = true
        ..input.boost = true;
      _fly(plain, 0.5);
      _fly(boosted, 0.5);
      expect(
        30 - boosted.position.x,
        closeTo(4 * (30 - plain.position.x), 1e-3),
      );
    });

    test('stops when the key is released', () {
      final navigator = lookingWest()..input.forward = true;
      _fly(navigator, 0.5);
      final stopped = navigator.position;

      navigator.input.forward = false;
      _fly(navigator, 0.5);

      expect(navigator.position, stopped);
    });

    test('strafing ignores pitch', () {
      final navigator = FlyNavigator(
        world: world,
        start: CameraPose(
          position: Vector3(30, 10, 0),
          target: Vector3(0, 0, 0),
        ),
      )..input.left = true;

      _fly(navigator, 1);

      expect(navigator.position.y, closeTo(10, 1e-4));
    });

    test('the slider sets a proportional forward or backward speed', () {
      final half = lookingWest()..input.throttle = 0.5;
      final full = lookingWest()..input.forward = true;
      final reverse = lookingWest()..input.throttle = -1;

      _fly(half, 1);
      _fly(full, 1);
      _fly(reverse, 1);

      expect(30 - half.position.x, closeTo((30 - full.position.x) / 2, 1e-3));
      expect(reverse.position.x, greaterThan(30));
    });

    test('looks with drags and with the trackball rate', () {
      final dragged = lookingWest()
        ..look(const Offset(100, 0))
        ..step(_dt);
      expect(dragged.forward.z, isNot(closeTo(0, 1e-3)));

      final trackball = lookingWest()..input.lookRate = const Offset(0, -100);
      _fly(trackball, 1);
      expect(trackball.forward.y, greaterThan(0.1));
    });

    test('stops at the surface of external package spheres', () {
      // Straight at the package sphere at (-20, 0, 0), radius 1.6.
      final navigator = FlyNavigator(
        world: world,
        start: CameraPose(
          position: Vector3(-10, 0, 0),
          target: Vector3(-20, 0, 0),
        ),
      )..input.forward = true;

      // 8 units at about 5 units per second: well within 3 seconds.
      _fly(navigator, 3);
      expect(navigator.position.x, closeTo(-20 + 1.6 + collisionMargin, 1e-4));

      // Pressing on, it never gets inside (it may slide along the surface).
      final center = world.obstacles.single.center;
      for (var i = 0; i < 300; i++) {
        navigator.step(_dt);
        expect(
          navigator.position.distanceTo(center),
          greaterThanOrEqualTo(1.6 + collisionMargin - 1e-4),
        );
      }
    });

    test('reports container changes and adapts the speed', () {
      final changes = <String?>[];
      final navigator = FlyNavigator(
        world: world,
        start: CameraPose(
          position: Vector3(4, 0, 10),
          target: Vector3(4, 0, 0),
        ),
        onContainerChanged: changes.add,
      )..input.forward = true;

      for (var i = 0; i < 600 && navigator.container == null; i++) {
        navigator.step(_dt);
      }

      expect(changes, ['A']);
      expect(navigator.container, 'A');
      // Class A has radius 2: speed baseSpeed × 2 / 10.
      expect(navigator.speed, closeTo(navigator.baseSpeed * 0.2, 1e-9));
    });

    test('reset returns to the start and releases the input', () {
      final navigator = lookingWest()
        ..input.forward = true
        ..look(const Offset(300, 0));
      _fly(navigator, 1);

      navigator
        ..reset()
        ..step(_dt);

      expect(navigator.position, Vector3(30, 5, 0));
      expect(navigator.input.forward, isFalse);
      expect(navigator.forward.x, closeTo(-1, 1e-6));
    });

    test('gives a camera at the current pose', () {
      final navigator = lookingWest();

      final camera = navigator.camera(const Size(800, 600));

      expect(camera.position, navigator.position);
      expect(camera.target, navigator.position + navigator.forward);
    });

    test('NavigationInput.clear releases everything', () {
      final input = NavigationInput()
        ..forward = true
        ..back = true
        ..left = true
        ..right = true
        ..up = true
        ..down = true
        ..boost = true
        ..throttle = 1
        ..lookRate = const Offset(1, 1)
        ..clear();

      expect([
        input.forward,
        input.back,
        input.left,
        input.right,
        input.up,
        input.down,
        input.boost,
      ], everyElement(isFalse));
      expect(input.throttle, 0);
      expect(input.lookRate, Offset.zero);
    });
  });
}
