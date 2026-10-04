import 'dart:async';

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/navigation/fly_navigator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

/// Turns keyboard, mouse and touch input into [navigator] input around the
/// 3D area [child].
///
/// | Input | Action |
/// |---|---|
/// | ↑ / ↓ | forward / back |
/// | ← / → | strafe |
/// | Page Up / Page Down, E / Q | up / down |
/// | Shift | boost |
/// | drag | look |
/// | Home | back to the start pose |
/// | ? | [onHelp] |
///
/// The area takes the keyboard focus when it appears and when tapped, so
/// the arrow keys fly instead of moving the focus.
class FlyControls extends StatefulWidget {
  const new({
    required this.navigator,
    required this.touchControls,
    required this.child,
    super.key,
    this.onHelp,
    this.platform,
  });

  /// The navigator driven.
  final FlyNavigator navigator;

  /// When the on-screen trackball and move control are shown.
  final TouchControlsMode touchControls;

  /// The 3D area.
  final Widget child;

  /// Shows the controls help.
  final VoidCallback? onHelp;

  /// The platform deciding automatic touch controls
  /// ([defaultTargetPlatform] by default).
  final TargetPlatform? platform;

  @override
  State<FlyControls> createState() => _FlyControlsState();
}

class _FlyControlsState extends State<FlyControls> {
  final _focusNode = FocusNode(debugLabel: 'fly controls');
  bool _keyboardUsed = false;
  bool _lastPointerWasTouch = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _showTouchControls => switch (widget.touchControls) {
    TouchControlsMode.always => true,
    TouchControlsMode.never => false,
    TouchControlsMode.auto =>
      switch (widget.platform ?? defaultTargetPlatform) {
            TargetPlatform.android || TargetPlatform.iOS => true,
            _ => false,
          } ||
          (_lastPointerWasTouch && !_keyboardUsed),
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final input = widget.navigator.input;
    final key = event.logicalKey;
    final pressed = event is! KeyUpEvent;
    if (!_keyboardUsed) setState(() => _keyboardUsed = true);
    if (key == LogicalKeyboardKey.arrowUp) {
      input.forward = pressed;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      input.back = pressed;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      input.left = pressed;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      input.right = pressed;
    } else if (key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.keyE) {
      input.up = pressed;
    } else if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.keyQ) {
      input.down = pressed;
    } else if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      input.boost = pressed;
    } else if (key == LogicalKeyboardKey.home) {
      if (event is KeyDownEvent) widget.navigator.reset();
    } else if (event.character == '?') {
      if (event is KeyDownEvent) widget.onHelp?.call();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    final touch = event.kind == PointerDeviceKind.touch;
    if (touch != _lastPointerWasTouch) {
      setState(() => _lastPointerWasTouch = touch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final input = widget.navigator.input;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: _onPointerDown,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => widget.navigator.look(details.delta),
              child: widget.child,
            ),
            if (_showTouchControls) ...[
              PositionedDirectional(
                start: spacing.md,
                bottom: spacing.xl * 2,
                child: MoveControl(
                  onThrottle: (value) => input.throttle = value,
                  onUp: (pressed) => input.up = pressed,
                  onDown: (pressed) => input.down = pressed,
                ),
              ),
              PositionedDirectional(
                end: spacing.md,
                bottom: spacing.xl * 2,
                child: Trackball(onRate: (rate) => input.lookRate = rate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A circular pad: holding a drag away from its center turns the view
/// continuously, faster the further from the center.
class Trackball extends StatefulWidget {
  const new({required this.onRate, super.key, this.size = 128});

  /// Called with the look rate (logical pixels per second), zero on release.
  final ValueChanged<Offset> onRate;

  /// The pad diameter.
  final double size;

  /// The look rate at the edge of the pad.
  static const double maxRate = 600;

  @override
  State<Trackball> createState() => _TrackballState();
}

class _TrackballState extends State<Trackball> {
  Offset _knob = Offset.zero;

  void _move(Offset local) {
    final radius = widget.size / 2;
    var offset = local - Offset(radius, radius);
    if (offset.distance > radius) offset = offset / offset.distance * radius;
    setState(() => _knob = offset);
    widget.onRate(offset / radius * Trackball.maxRate);
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onRate(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.viewerTouchLook,
      child: GestureDetector(
        onPanStart: (details) {
          unawaited(HapticFeedback.selectionClick());
          _move(details.localPosition);
        },
        onPanUpdate: (details) => _move(details.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
            border: Border.all(color: colors.outline),
          ),
          alignment: Alignment.center,
          child: Transform.translate(
            offset: _knob,
            child: Icon(Icons.threesixty, size: 40, color: colors.primary),
          ),
        ),
      ),
    );
  }
}

/// A vertical slider (up: forward, down: back, proportional) with buttons
/// to fly up and down.
class MoveControl extends StatefulWidget {
  const new({
    required this.onThrottle,
    required this.onUp,
    required this.onDown,
    super.key,
    this.height = 160,
  });

  /// Called with the throttle, -1 (back) to 1 (forward), zero on release.
  final ValueChanged<double> onThrottle;

  /// Called when the up button is pressed and released.
  final ValueChanged<bool> onUp;

  /// Called when the down button is pressed and released.
  final ValueChanged<bool> onDown;

  /// The slider height.
  final double height;

  @override
  State<MoveControl> createState() => _MoveControlState();
}

class _MoveControlState extends State<MoveControl> {
  double _throttle = 0;

  void _move(Offset local) {
    final half = widget.height / 2;
    final throttle = ((half - local.dy) / half).clamp(-1.0, 1.0);
    setState(() => _throttle = throttle);
    widget.onThrottle(throttle);
  }

  void _release() {
    setState(() => _throttle = 0);
    widget.onThrottle(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final spacing = context.spacing;
    Widget button(IconData icon, String label, ValueChanged<bool> onPress) =>
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTapDown: (_) {
              unawaited(HapticFeedback.selectionClick());
              onPress(true);
            },
            onTapUp: (_) => onPress(false),
            onTapCancel: () => onPress(false),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
                border: Border.all(color: colors.outline),
              ),
              child: Icon(icon, color: colors.primary),
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l10n.viewerTouchMove,
          child: GestureDetector(
            onVerticalDragStart: (details) {
              unawaited(HapticFeedback.selectionClick());
              _move(details.localPosition);
            },
            onVerticalDragUpdate: (details) => _move(details.localPosition),
            onVerticalDragEnd: (_) => _release(),
            onVerticalDragCancel: _release,
            child: Container(
              width: 56,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
                border: Border.all(color: colors.outline),
              ),
              alignment: Alignment(0, -_throttle * 0.75),
              child: Icon(Icons.unfold_more, size: 32, color: colors.primary),
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Icons.keyboard_arrow_up, l10n.viewerFlyUp, widget.onUp),
            SizedBox(height: spacing.sm),
            button(
              Icons.keyboard_arrow_down,
              l10n.viewerFlyDown,
              widget.onDown,
            ),
          ],
        ),
      ],
    );
  }
}

/// Lists the keyboard and touch controls.
class ControlsHelpDialog extends StatelessWidget {
  const new({super.key});

  /// Shows the dialog.
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ControlsHelpDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget keys(String text) => Text(text, style: theme.textTheme.labelLarge);
    Widget icons(List<IconData> data) => Wrap(
      spacing: context.spacing.xs,
      children: [for (final icon in data) Icon(icon, size: 20)],
    );
    // The app font has no arrow or mouse glyphs: icons draw them.
    final rows = <(Widget, String)>[
      (
        icons(const [
          Icons.arrow_upward,
          Icons.arrow_downward,
          Icons.arrow_back,
          Icons.arrow_forward,
        ]),
        l10n.viewerKeyMove,
      ),
      (keys('Page Up / Page Down · E / Q'), l10n.viewerKeyUpDown),
      (keys('Shift'), l10n.viewerKeyBoost),
      (icons(const [Icons.mouse_outlined]), l10n.viewerKeyLook),
      (keys('Home'), l10n.viewerKeyHome),
      (keys('?'), l10n.viewerKeyHelp),
    ];
    return AlertDialog(
      title: Text(l10n.viewerControlsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (keys, action) in rows)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 140, child: keys),
                    Expanded(child: Text(action)),
                  ],
                ),
              ),
            const Divider(),
            Text(l10n.viewerTouchLook),
            Text(l10n.viewerTouchMove),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.viewerClose),
        ),
      ],
    );
  }
}
