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

    test('keeps slowing down in spheres nested deep, tiny', () {
      final tiny = scaleNested(scaleNested(scaleNested(nestedMap())));
      final deep = CodeWorld(tiny, CodeWorldColors.light);
      final navigator = FlyNavigator(
        world: deep,
        start: CameraPose(
          position: deep.positions['A.B']!,
          target: deep.positions['A.B']! + Vector3(0, 0, -1),
        ),
      )..step(_dt); // Settles the container tracking.

      // A.B is drawn 1 × 0.5³ across: its speed is under the old floor.
      expect(navigator.container, 'A.B');
      expect(navigator.speed, lessThan(navigator.baseSpeed * 0.05 / 2));
      expect(navigator.speed, greaterThan(0));
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

    group('flights', () {
      final destination = CameraPose(
        position: Vector3(30, 5, 20),
        target: Vector3(30, 5, 0),
      );

      test('go smoothly to the destination and look where asked', () {
        final navigator = lookingWest()..flyTo(destination);
        expect(navigator.isFlying, isTrue);

        _fly(navigator, 0.5);
        // Smooth start and stop: halfway in time is halfway in space.
        expect(navigator.isFlying, isTrue);
        expect(navigator.position.z, closeTo(10, 0.2));
        expect(navigator.position.x, closeTo(30, 1e-3));

        _fly(navigator, 0.6);
        expect(navigator.isFlying, isFalse);
        expect(
          navigator.position.distanceTo(destination.position),
          lessThan(1e-3),
        );
        expect(navigator.forward.z, closeTo(-1, 1e-3));
      });

      test('turn the view while flying', () {
        // Looking west to looking north: the direction is blended.
        final navigator = lookingWest()..flyTo(destination);

        _fly(navigator, 0.5);

        expect(navigator.forward.length, closeTo(1, 1e-6));
        expect(navigator.forward.x, lessThan(-0.3));
        expect(navigator.forward.z, lessThan(-0.3));
        expect(navigator.pose.position, navigator.position);
      });

      test('turn all the way round without a blank direction', () {
        final navigator = lookingWest()
          ..flyTo(
            CameraPose(position: Vector3(30, 5, 0), target: Vector3(40, 5, 0)),
          );

        _fly(navigator, 0.5);

        expect(navigator.forward.length, closeTo(1, 1e-6));
        _fly(navigator, 0.6);
        expect(navigator.forward.x, closeTo(1, 1e-3));
      });

      test('jump when not animated, or when they take no time', () {
        final jumped = lookingWest()..flyTo(destination, animate: false);
        final instant = lookingWest()..flyTo(destination, duration: 0);

        for (final navigator in [jumped, instant]) {
          expect(navigator.isFlying, isFalse);
          expect(
            navigator.position.distanceTo(destination.position),
            lessThan(1e-3),
          );
        }
      });

      test('report the sphere they end in', () {
        final changes = <String?>[];
        final navigator =
            FlyNavigator(
              world: world,
              start: CameraPose(
                position: Vector3(30, 5, 0),
                target: Vector3(0, 5, 0),
              ),
              onContainerChanged: changes.add,
            )..flyTo(
              CameraPose(position: Vector3(4, 0, 1), target: Vector3(4, 0, 0)),
            );

        _fly(navigator, 1.2);

        expect(changes, ['A']);
        expect(navigator.container, 'A');
      });

      test('report a sphere reached by jumping', () {
        final changes = <String?>[];
        FlyNavigator(
          world: world,
          start: CameraPose(
            position: Vector3(30, 5, 0),
            target: Vector3(0, 5, 0),
          ),
          onContainerChanged: changes.add,
        ).flyTo(
          CameraPose(position: Vector3(4, 0, 1), target: Vector3(4, 0, 0)),
          animate: false,
        );

        expect(changes, ['A']);
      });

      test('are taken back by any input', () {
        final navigator = lookingWest()..flyTo(destination);
        _fly(navigator, 0.5);
        final halfway = navigator.position;

        navigator.input.forward = true;
        navigator.step(_dt);

        expect(navigator.isFlying, isFalse);
        expect(navigator.position.distanceTo(halfway), lessThan(1.5));
        expect(navigator.position.z, lessThan(destination.position.z - 5));
      });

      test('end outside solid spheres', () {
        final navigator = lookingWest()
          ..flyTo(
            CameraPose(position: Vector3(-20, 0, 0), target: Vector3(0, 0, 0)),
            animate: false,
          );

        expect(
          navigator.position.distanceTo(world.obstacles.single.center),
          closeTo(1.6 + collisionMargin, 1e-3),
        );
      });

      test('push the camera out of solid spheres on the way', () {
        final navigator = lookingWest()
          ..flyTo(
            CameraPose(position: Vector3(-30, 0, 0), target: Vector3(0, 0, 0)),
          );
        final center = world.obstacles.single.center;

        for (var i = 0; i < 40; i++) {
          navigator.step(_dt);
          expect(
            navigator.position.distanceTo(center),
            greaterThanOrEqualTo(1.6 + collisionMargin - 1e-3),
          );
        }
      });

      test('stop on reset', () {
        final navigator = lookingWest()..flyTo(destination);
        _fly(navigator, 0.3);

        navigator.reset();

        expect(navigator.isFlying, isFalse);
        expect(navigator.position, Vector3(30, 5, 0));
      });
    });

    group('flights along several poses', () {
      late CodeWorld nested;

      setUp(() => nested = CodeWorld(nestedMap(), CodeWorldColors.light));

      FlyNavigator startingAt(Vector3 position, {List<String?>? changes}) =>
          FlyNavigator(
            world: nested,
            start: CameraPose(position: position, target: Vector3.zero()),
            onContainerChanged: changes?.add,
          );

      CameraPose landing(String? container) => exitPose(
        world: nested,
        target: container,
        from: Vector3(40, 0, 0),
        current: null,
      );

      test('report the container at each pose they pass, in order', () {
        final changes = <String?>[];
        final navigator = startingAt(Vector3(40, 0, 0), changes: changes)
          ..flyAlong([landing('A'), landing('A.B')]);

        _fly(navigator, 2);

        expect(changes, ['A', 'A.B']);
        expect(navigator.isFlying, isFalse);
        expect(navigator.container, 'A.B');
      });

      test('do not report the spheres crossed between two poses', () {
        final changes = <String?>[];
        // Straight along X, through C and then through A.
        final navigator = startingAt(Vector3(40, 0, 0), changes: changes)
          ..flyAlong([
            CameraPose(
              position: Vector3(-10, 0, 0),
              target: Vector3(-20, 0, 0),
            ),
          ]);

        _fly(navigator, 2);

        expect(changes, isEmpty);
        expect(navigator.container, isNull);
        expect(navigator.position.x, closeTo(-10, 1e-3));
      });

      test('report every pose reached in a single long step', () {
        final changes = <String?>[];
        final navigator = startingAt(Vector3(40, 0, 0), changes: changes)
          ..flyAlong([landing('A'), landing('A.B')])
          ..step(10);

        expect(changes, ['A', 'A.B']);
        expect(navigator.isFlying, isFalse);
      });

      test('jump to the last pose without animation', () {
        final changes = <String?>[];
        final navigator = startingAt(Vector3(40, 0, 0), changes: changes)
          ..flyAlong([landing('A'), landing('A.B')], animate: false);

        expect(navigator.isFlying, isFalse);
        expect(navigator.container, 'A.B');
        expect(changes, ['A.B']);
      });

      test('take 0.6 s for a hop and 1.5 s across the world', () {
        final hop = startingAt(Vector3(40, 0, 0))
          ..flyAlong([
            CameraPose(position: Vector3(39, 0, 0), target: Vector3.zero()),
          ]);
        final across = startingAt(Vector3(40, 0, 0))
          ..flyAlong([
            CameraPose(position: Vector3(-40, 0, 0), target: Vector3.zero()),
          ]);

        _fly(hop, 0.7);
        _fly(across, 1.4);

        expect(hop.isFlying, isFalse);
        expect(across.isFlying, isTrue);
        _fly(across, 0.2);
        expect(across.isFlying, isFalse);
      });

      test('complete, turning, even when they go nowhere', () {
        final navigator = startingAt(Vector3(40, 0, 0))
          ..flyAlong([
            CameraPose(
              position: Vector3(40, 0, 0),
              target: Vector3(40, 0, -10),
            ),
          ]);

        _fly(navigator, 1);

        expect(navigator.isFlying, isFalse);
        expect(navigator.forward.z, closeTo(-1, 1e-3));
      });
    });

    group('notifications', () {
      late int notified;
      late FlyNavigator navigator;

      setUp(() {
        notified = 0;
        navigator = lookingWest()..addListener(() => notified++);
      });

      test('come when the camera moves', () {
        navigator.input.forward = true;

        navigator
          ..step(_dt)
          ..step(_dt);

        expect(notified, 2);
      });

      test('come when the camera turns', () {
        navigator
          ..look(const Offset(50, 0))
          ..step(_dt);

        expect(notified, 1);
      });

      test('do not come when nothing changes', () {
        navigator.step(_dt);
        final first = notified;

        navigator
          ..step(_dt)
          ..step(_dt);

        expect(notified, first);
      });

      test('come when the camera jumps or goes back to the start', () {
        navigator.step(_dt);
        final before = notified;

        navigator.flyTo(
          CameraPose(position: Vector3(20, 5, 0), target: Vector3(0, 5, 0)),
          animate: false,
        );
        expect(notified, before + 1);

        navigator.reset();
        expect(notified, before + 2);
      });

      test('come during a flight', () {
        navigator.flyTo(
          CameraPose(position: Vector3(30, 5, 20), target: Vector3(30, 5, 0)),
        );

        _fly(navigator, 0.5);

        expect(notified, greaterThan(5));
      });
    });

    test('gives a view camera for the current pose', () {
      final navigator = lookingWest();
      const size = Size(390, 844);

      final camera = navigator.viewCamera(size);

      expect(camera.position, navigator.position);
      expect(camera.forward.distanceTo(navigator.forward), lessThan(1e-6));
      expect(camera.fovY, world.fovYFor(size));
      expect(camera.size, size);
    });

    test('NavigationInput.active tells when something is held', () {
      expect((NavigationInput()..forward = true).active, isTrue);
      expect((NavigationInput()..back = true).active, isTrue);
      expect((NavigationInput()..left = true).active, isTrue);
      expect((NavigationInput()..right = true).active, isTrue);
      expect((NavigationInput()..up = true).active, isTrue);
      expect((NavigationInput()..down = true).active, isTrue);
      expect((NavigationInput()..throttle = 0.5).active, isTrue);
      expect((NavigationInput()..lookRate = const Offset(1, 0)).active, isTrue);
      // Boost alone moves nothing.
      expect((NavigationInput()..boost = true).active, isFalse);
      expect(NavigationInput().active, isFalse);
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
