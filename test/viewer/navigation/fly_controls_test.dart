import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

void main() {
  group(FlyControls, () {
    late FlyNavigator navigator;
    late int helpShown;
    late int viewToggled;
    late List<(Offset, Size)> taps;
    late List<Size> centersSelected;
    late int deselected;
    late int labelsToggled;
    late int searched;

    setUp(() {
      taps = [];
      centersSelected = [];
      deselected = 0;
      labelsToggled = 0;
      searched = 0;
      navigator = FlyNavigator(
        world: CodeWorld(worldMap(), CodeWorldColors.light),
      );
      helpShown = 0;
      viewToggled = 0;
    });

    Future<void> pump(
      WidgetTester tester, {
      TouchControlsMode mode = TouchControlsMode.never,
      TargetPlatform platform = TargetPlatform.linux,
      bool hideTouchControls = false,
    }) => tester.pumpApp(
      FlyControls(
        navigator: navigator,
        touchControls: mode,
        hideTouchControls: hideTouchControls,
        platform: platform,
        onHelp: () => helpShown++,
        onToggleViewMode: () => viewToggled++,
        onTap: (position, size) => taps.add((position, size)),
        onSelectCenter: centersSelected.add,
        onDeselect: () => deselected++,
        onToggleLabels: () => labelsToggled++,
        onSearch: () => searched++,
        child: const ColoredBox(color: Colors.black),
      ),
    );

    group('keyboard', () {
      testWidgets('holds the flight keys while pressed', (tester) async {
        await pump(tester);
        final input = navigator.input;
        final keys = <LogicalKeyboardKey, bool Function()>{
          LogicalKeyboardKey.arrowUp: () => input.forward,
          LogicalKeyboardKey.arrowDown: () => input.back,
          LogicalKeyboardKey.arrowLeft: () => input.left,
          LogicalKeyboardKey.arrowRight: () => input.right,
          LogicalKeyboardKey.pageUp: () => input.up,
          LogicalKeyboardKey.keyE: () => input.up,
          LogicalKeyboardKey.pageDown: () => input.down,
          LogicalKeyboardKey.keyQ: () => input.down,
          LogicalKeyboardKey.shiftLeft: () => input.boost,
          LogicalKeyboardKey.shiftRight: () => input.boost,
        };

        for (final MapEntry(:key, value: held) in keys.entries) {
          await tester.sendKeyDownEvent(key);
          expect(held(), isTrue, reason: '$key down');
          await tester.sendKeyRepeatEvent(key);
          expect(held(), isTrue, reason: '$key repeat');
          await tester.sendKeyUpEvent(key);
          expect(held(), isFalse, reason: '$key up');
        }
      });

      testWidgets('Home returns to the start pose', (tester) async {
        await pump(tester);
        navigator.input.forward = true;
        for (var i = 0; i < 30; i++) {
          navigator.step(1 / 30);
        }

        await tester.sendKeyDownEvent(LogicalKeyboardKey.home);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.home);
        navigator.step(1 / 30);

        expect(navigator.position, navigator.start.position);
      });

      testWidgets('? shows the help', (tester) async {
        await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '?');
        await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);

        expect(helpShown, 1);
      });

      testWidgets('V switches between inside and window view', (tester) async {
        await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);

        expect(viewToggled, 2);
      });

      testWidgets('L shows or hides the labels', (tester) async {
        await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);

        expect(labelsToggled, 1);
      });

      testWidgets('Enter selects what is in the middle of the view', (
        tester,
      ) async {
        await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.numpadEnter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.numpadEnter);

        expect(centersSelected, [const Size(800, 600), const Size(800, 600)]);
      });

      testWidgets('Esc deselects', (tester) async {
        await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

        expect(deselected, 1);
      });

      testWidgets('/ opens the search', (tester) async {
        await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '/');
        await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);

        expect(searched, 1);
        expect(helpShown, 0);
      });

      testWidgets('Ctrl+F and Cmd+F open the search', (tester) async {
        await pump(tester);

        for (final modifier in [
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.metaLeft,
        ]) {
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
          await tester.sendKeyUpEvent(modifier);
        }

        expect(searched, 2);
      });

      testWidgets('F alone is not a shortcut', (tester) async {
        await pump(tester);

        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyF);

        expect(handled, isFalse);
        expect(searched, 0);
      });

      testWidgets('lets other keys through', (tester) async {
        await pump(tester);

        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);

        expect(handled, isFalse);
      });
    });

    group('taps', () {
      testWidgets('are reported with their position and the view size', (
        tester,
      ) async {
        await pump(tester);

        await tester.tapAt(const Offset(120, 340));

        expect(taps, [(const Offset(120, 340), const Size(800, 600))]);
      });

      testWidgets('are not reported when the finger drags', (tester) async {
        await pump(tester);

        await tester.dragFrom(const Offset(300, 300), const Offset(100, 0));

        expect(taps, isEmpty);
      });
    });

    testWidgets('dragging the scene looks around', (tester) async {
      await pump(tester);
      final before = navigator.forward;

      await tester.drag(find.byType(ColoredBox).last, const Offset(200, 0));
      navigator.step(1 / 30);

      expect(navigator.forward.distanceTo(before), greaterThan(0.1));
    });

    testWidgets('takes the focus when tapped', (tester) async {
      await pump(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.tap(find.byType(ColoredBox).last);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);

      expect(navigator.input.forward, isTrue);
    });

    group('touch controls', () {
      testWidgets('follow the setting', (tester) async {
        await pump(tester, mode: TouchControlsMode.always);
        expect(find.byType(Trackball), findsOneWidget);
        expect(find.byType(MoveControl), findsOneWidget);

        await pump(tester, platform: TargetPlatform.android);
        expect(find.byType(Trackball), findsNothing);
      });

      testWidgets('can be hidden whatever the setting says', (tester) async {
        await pump(
          tester,
          mode: TouchControlsMode.always,
          hideTouchControls: true,
        );

        expect(find.byType(Trackball), findsNothing);
        expect(find.byType(MoveControl), findsNothing);
      });

      testWidgets('appear automatically on phones', (tester) async {
        for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
          await pump(tester, mode: TouchControlsMode.auto, platform: platform);
          expect(find.byType(Trackball), findsOneWidget);
        }
      });

      testWidgets('appear after touch input until a key is used', (
        tester,
      ) async {
        await pump(tester, mode: TouchControlsMode.auto);
        expect(find.byType(Trackball), findsNothing);

        await tester.tap(find.byType(ColoredBox).last);
        await tester.pump();
        expect(find.byType(Trackball), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(find.byType(Trackball), findsNothing);

        await tester.tap(find.byType(ColoredBox).last);
        await tester.pump();
        expect(find.byType(Trackball), findsNothing);
      });

      testWidgets('the trackball turns while held', (tester) async {
        await pump(tester, mode: TouchControlsMode.always);
        final center = tester.getCenter(find.byType(Trackball));

        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        final rate = navigator.input.lookRate;
        await gesture.moveBy(const Offset(400, 0));
        await tester.pump();
        final clamped = navigator.input.lookRate;
        await gesture.up();
        await tester.pump();

        expect(rate.dx, greaterThan(0));
        expect(clamped.dx, closeTo(Trackball.maxRate, 1e-6));
        expect(navigator.input.lookRate, Offset.zero);
      });

      testWidgets('the trackball releases on cancel', (tester) async {
        await pump(tester, mode: TouchControlsMode.always);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Trackball)),
        );
        await gesture.moveBy(const Offset(40, 0));
        await gesture.cancel();
        await tester.pump();

        expect(navigator.input.lookRate, Offset.zero);
      });

      testWidgets('the slider sets a proportional throttle', (tester) async {
        await pump(tester, mode: TouchControlsMode.always);
        final slider = find.bySemanticsLabel('Slider: fly forward or back');
        final center = tester.getCenter(slider);

        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump();
        final forward = navigator.input.throttle;
        await gesture.moveBy(const Offset(0, 400));
        await tester.pump();
        final back = navigator.input.throttle;
        await gesture.up();
        await tester.pump();

        expect(forward, greaterThan(0));
        expect(back, -1);
        expect(navigator.input.throttle, 0);

        final cancelled = await tester.startGesture(center);
        await cancelled.moveBy(const Offset(0, -40));
        await cancelled.cancel();
        await tester.pump();
        expect(navigator.input.throttle, 0);
      });

      testWidgets('the up and down buttons fly while pressed', (tester) async {
        await pump(tester, mode: TouchControlsMode.always);

        for (final (label, held) in [
          ('Fly up', () => navigator.input.up),
          ('Fly down', () => navigator.input.down),
        ]) {
          final button = find.bySemanticsLabel(label);
          final gesture = await tester.startGesture(tester.getCenter(button));
          await tester.pump();
          expect(held(), isTrue);
          await gesture.up();
          await tester.pump();
          expect(held(), isFalse);

          final cancelled = await tester.startGesture(tester.getCenter(button));
          await tester.pump();
          await cancelled.moveBy(const Offset(0, 200));
          await cancelled.up();
          await tester.pump();
          expect(held(), isFalse);
        }
      });

      testWidgets('meet the tap target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, mode: TouchControlsMode.always);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  });

  group(ControlsHelpDialog, () {
    testWidgets('lists the controls and closes', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => ControlsHelpDialog.show(context),
            child: const Text('help'),
          ),
        ),
      );

      await tester.tap(find.text('help'));
      await tester.pumpAndSettle();
      expect(find.text('Flying controls'), findsOneWidget);
      expect(find.text('Back to the start'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Flying controls'), findsNothing);
    });
  });
}
