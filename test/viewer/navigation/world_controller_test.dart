import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(WorldController, () {
    late CodeWorld world;
    late FlyNavigator navigator;
    late WorldController controller;

    setUp(() {
      world = CodeWorld(nestedMap(), CodeWorldColors.light);
      navigator = FlyNavigator(world: world);
      controller = WorldController()..attach(navigator);
    });

    test('flies into a container', () {
      controller.flyToContainer('A', animate: false);

      expect(navigator.container, 'A');
      expect(navigator.isFlying, isFalse);
    });

    test('flies out to the world', () {
      controller
        ..flyToContainer('A', animate: false)
        ..flyToContainer(null, animate: false);

      expect(navigator.container, isNull);
    });

    test('animates when allowed', () {
      controller.flyToContainer('A', animate: true);

      expect(navigator.isFlying, isTrue);
      expect(navigator.container, isNull);
    });

    test('does nothing without a navigator', () {
      controller
        ..detach(navigator)
        ..flyToContainer('A', animate: false);

      expect(navigator.container, isNull);
    });

    test('ignores the detaching of another navigator', () {
      final other = FlyNavigator(world: world);

      controller
        ..detach(other)
        ..flyToContainer('A', animate: false);

      expect(navigator.container, 'A');
    });

    test('flies to a node, following the containment', () {
      controller.flyToNode('A.B.n', animate: false);

      expect(navigator.container, 'A.B');
      // Facing the node: the camera looks straight at its center.
      final toNode = (world.positions['A.B.n']! - navigator.position)
        ..normalize();
      expect(navigator.forward.distanceTo(toNode), lessThan(1e-4));
    });

    test('animates the flight to a node when allowed', () {
      controller.flyToNode('C.k', animate: true);

      expect(navigator.isFlying, isTrue);
      for (var i = 0; i < 90; i++) {
        navigator.step(1 / 30);
      }
      expect(navigator.isFlying, isFalse);
      expect(navigator.container, 'C');
    });

    test('does not fly to a node without a navigator', () {
      controller
        ..detach(navigator)
        ..flyToNode('C', animate: false);

      expect(navigator.container, isNull);
    });

    test('exposes the navigator it controls', () {
      expect(controller.navigator, same(navigator));

      controller.detach(navigator);

      expect(controller.navigator, isNull);
    });

    test('tells its listeners when the camera moves', () {
      var notified = 0;
      controller.addListener(() => notified++);

      navigator.input.forward = true;
      navigator.step(1 / 30);

      expect(notified, 1);
    });

    test(
      'tells its listeners, once the view is built, that it is attached',
      () async {
        var notified = 0;
        final fresh = WorldController()
          ..addListener(() => notified++)
          ..attach(navigator);
        expect(notified, 0);
        await Future<void>.delayed(Duration.zero);

        expect(notified, 1);
        fresh.dispose();
      },
    );

    test('stops following a navigator that was replaced', () {
      final other = FlyNavigator(world: world);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..attach(other);
      navigator
        ..input.forward = true
        ..step(1 / 30);

      expect(notified, 0);
      expect(controller.navigator, same(other));
    });

    test('stops following when disposed, even before it was told', () async {
      final fresh = WorldController()..attach(navigator);
      var notified = 0;
      fresh
        ..addListener(() => notified++)
        ..dispose();

      navigator.input.forward = true;
      navigator.step(1 / 30);
      await Future<void>.delayed(Duration.zero);

      expect(notified, 0);
    });

    test('exposes the pose it flew to', () {
      controller.flyToContainer('A', animate: false);

      expect(navigator.position.length, closeTo(3 * insideShellShare, 1e-3));
      expect(
        navigator.pose.target.distanceTo(
          navigator.position + navigator.forward,
        ),
        lessThan(1e-6),
      );
    });
  });
}
