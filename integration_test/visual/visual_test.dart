// Captures every visual scenario at every golden size, in light and dark
// themes, checks each frame is a sane render, and hands the PNGs to
// test_driver/visual_driver.dart, which compares them with the baselines.
// Run it with tool/visual_test.sh (repo root of hawkbee).

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/helpers/goldens.dart';
import 'frame_stats.dart';
import 'visual_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final captures = <String, String>{};

  group('3D visual scenario', () {
    tearDownAll(() => binding.reportData = {'captures': captures});

    for (final scenario in visualScenarios) {
      for (final device in GoldenDevice.values) {
        for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
          final name = '${scenario.id}/${device.name}_${themeMode.name}';
          testWidgets('$name renders a sane frame', (tester) async {
            final theme = themeMode == ThemeMode.light
                ? AppTheme.light
                : AppTheme.dark;
            // The 3D view paints the world background (CodeWorldColors).
            final clear = theme.extension<CodeWorldColors>()!.background;
            final boundaryKey = GlobalKey();

            // One ordinary frame first so the GPU context exists before
            // flutter_scene uploads anything.
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await Scene.initializeStaticResources();
            final builder = await scenario.load();

            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                // The captured size may exceed the window: lay it out
                // unconstrained, toImage renders the whole boundary.
                home: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: SizedBox.fromSize(
                      size: device.size,
                      child: ColoredBox(
                        color: clear,
                        child: Builder(builder: builder),
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Let the scene settle (shaders, environment, first GPU frames).
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            for (var i = 0; i < 20; i++) {
              boundary.markNeedsPaint();
              await tester.pump(const Duration(milliseconds: 50));
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }

            final image = await boundary.toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final rgba = await image.toByteData();
            captures['$name.png'] = base64Encode(png!.buffer.asUint8List());

            final stats = FrameStats.of(
              rgba!.buffer.asUint8List(),
              width: image.width,
              height: image.height,
              clear: (
                r: (clear.r * 255).round(),
                g: (clear.g * 255).round(),
                b: (clear.b * 255).round(),
              ),
            );
            // The per-frame stats are the first thing to read when a check
            // fails, so print them to the test log.
            // ignore: avoid_print
            print('VISUAL $name ${image.width}x${image.height} $stats');

            expect(
              image.width,
              device.size.width,
              reason: 'capture has the wrong width',
            );
            expect(
              stats.cornersClear || !scenario.clearCorners,
              isTrue,
              reason: 'corners are not the background; the frame is wrong',
            );
            expect(
              stats.centerCoverage,
              greaterThan(0.05),
              reason: 'little or nothing drew in the center',
            );
            expect(
              stats.foregroundLuma,
              greaterThan(20),
              reason: 'the drawn content is almost black; lighting is broken',
            );
          });
        }
      }
    }
  });
}
