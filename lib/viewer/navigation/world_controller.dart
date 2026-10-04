import 'package:dart_code_3d/viewer/navigation/exit_pose.dart';
import 'package:dart_code_3d/viewer/navigation/fly_navigator.dart';

/// Lets the HUD move the camera of a `CodeWorldView` it does not own, like
/// a `TextEditingController` for a text field.
class WorldController {
  FlyNavigator? _navigator;

  /// Called by the view that owns [navigator].
  // ignore: use_setters_to_change_properties
  void attach(FlyNavigator navigator) => _navigator = navigator;

  /// Called when [navigator] goes away.
  void detach(FlyNavigator navigator) {
    if (identical(_navigator, navigator)) _navigator = null;
  }

  /// Flies out (or in) to [containerId] (the world when null): just inside
  /// that container's shell, or just outside the top-level sphere holding the
  /// camera. Jumps there without [animate].
  void flyToContainer(String? containerId, {required bool animate}) {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.flyTo(
      exitPose(
        world: navigator.world,
        target: containerId,
        from: navigator.position,
        current: navigator.container,
      ),
      animate: animate,
    );
  }
}
