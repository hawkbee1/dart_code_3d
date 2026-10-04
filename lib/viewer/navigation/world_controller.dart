import 'dart:async';

import 'package:dart_code_3d/viewer/navigation/exit_pose.dart';
import 'package:dart_code_3d/viewer/navigation/fly_navigator.dart';
import 'package:dart_code_3d/viewer/navigation/fly_plan.dart';
import 'package:flutter/foundation.dart';

/// Lets the HUD move the camera of a `CodeWorldView` it does not own, like
/// a `TextEditingController` for a text field, and follow it: it notifies
/// its listeners whenever the camera moves.
class WorldController extends ChangeNotifier {
  FlyNavigator? _navigator;
  bool _disposed = false;

  /// The navigator of the view this controls, once it is attached.
  FlyNavigator? get navigator => _navigator;

  /// Called by the view that owns [navigator].
  void attach(FlyNavigator navigator) {
    _navigator?.removeListener(notifyListeners);
    _navigator = navigator..addListener(notifyListeners);
    // Attaching happens while the view builds: tell the listeners after.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  /// Called when [navigator] goes away.
  void detach(FlyNavigator navigator) {
    if (!identical(_navigator, navigator)) return;
    navigator.removeListener(notifyListeners);
    _navigator = null;
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

  /// Flies to node [id], following the containment (out of the containers
  /// that do not hold it, into the ones that do) and ends facing it. Jumps
  /// there without [animate].
  void flyToNode(String id, {required bool animate}) {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.flyAlong(
      flyToNodePlan(
        world: navigator.world,
        from: navigator.position,
        current: navigator.container,
        target: id,
      ),
      animate: animate,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _navigator?.removeListener(notifyListeners);
    super.dispose();
  }
}
