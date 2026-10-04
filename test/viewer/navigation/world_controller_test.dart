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
