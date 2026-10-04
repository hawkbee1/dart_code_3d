// End to end, through the real UI and the network: analyzes a public git
// repository, waits for the viewer, checks the map is listed on the home
// screen, and captures the viewer. Opt-in (it needs the network and takes
// minutes): run it with tool/e2e_test.sh (repo root of hawkbee).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:code_map_repository/code_map_repository.dart';
import 'package:code_source_client/code_source_client.dart';
import 'package:dart_code_3d/analysis/cubit/source_form_cubit.dart';
import 'package:dart_code_3d/analysis/widgets/source_form.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/app/storage/file_code_map_store.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual/frame_stats.dart';

const _url = String.fromEnvironment(
  'DC3D_E2E_URL',
  defaultValue: 'https://github.com/bdero/flutter_scene',
);
const _ref = String.fromEnvironment(
  'DC3D_E2E_REF',
  defaultValue: 'flutter_scene-0.23.0',
);

/// Prints to the test log: the first thing to read when a run goes wrong.
void log(String message) {
  // A test log has no logger: flutter drive shows what is printed.
  // ignore: avoid_print
  print('E2E $message');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final report = <String, Object?>{};

  tearDownAll(() => binding.reportData = report);

  testWidgets('analyzes a public repository and opens it in 3D', (
    tester,
  ) async {
    final storage = Directory.systemTemp.createTempSync('dc3d_e2e_');
    addTearDown(() => storage.deleteSync(recursive: true));

    // One ordinary frame first so the GPU context exists before
    // flutter_scene uploads anything.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await Scene.initializeStaticResources();

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: App(
          settingsRepository: SettingsRepository(
            preferences: SharedPreferencesAsync(),
          ),
          codeMapRepository: CodeMapRepository(
            sourceClient: CodeSourceClient(),
            store: FileCodeMapStore(Directory('${storage.path}/code_maps')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    /// The texts on the screen, to say where a wait is stuck.
    String screen() => find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(40)
        .join(' | ');

    /// What the form holds and whether it can start, to say why it did not.
    String form() {
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text)
          .toList();
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Analyze'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      return 'fields $fields, Analyze enabled: ${button.onPressed != null}';
    }

    /// Pumps in real time until [finder] matches; fails after [limit], or at
    /// once when the analysis shows its failure screen or never started.
    Future<void> waitFor(Finder finder, Duration limit) async {
      final clock = Stopwatch()..start();
      var lastReport = Duration.zero;
      while (finder.evaluate().isEmpty) {
        if (find.text('Change source').evaluate().isNotEmpty) {
          fail('the analysis failed: ${screen()}');
        }
        if (clock.elapsed > const Duration(seconds: 20) &&
            find.text('Analyze').evaluate().isNotEmpty) {
          fail('the analysis never started: ${form()}');
        }
        if (clock.elapsed > limit) {
          fail(
            '${finder.describeMatch(Plurality.one)} never appeared; '
            'the screen shows: ${screen()}',
          );
        }
        if (clock.elapsed - lastReport > const Duration(seconds: 20)) {
          lastReport = clock.elapsed;
          log('waiting (${clock.elapsed.inSeconds} s): ${screen()}');
        }
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // The home screen, with nothing stored.
    expect(find.text('No code maps yet'), findsOneWidget);

    await tester.tap(find.text('New analysis'));
    await tester.pumpAndSettle();
    // Typing is covered by the widget tests; a live integration run does not
    // deliver `enterText` to the fields on Linux, so fill them directly.
    final fields = find.byType(TextField);
    tester.widget<TextField>(fields.at(0)).controller!.text = _url;
    tester.widget<TextField>(fields.at(1)).controller!.text = _ref;
    tester.element(find.byType(SourceForm)).read<SourceFormCubit>()
      ..urlChanged(_url)
      ..refChanged(_ref);
    await tester.pump();

    final analysis = Stopwatch()..start();
    log('before Analyze: ${form()}');
    await tester.tap(find.text('Analyze'));
    await tester.pump();
    log('after Analyze: ${screen()}');
    await waitFor(find.byType(ViewerView), const Duration(minutes: 5));
    analysis.stop();
    report['analysis_seconds'] = analysis.elapsed.inMilliseconds / 1000;
    report['url'] = _url;
    report['ref'] = _ref;

    // The viewer opens the stored map; let the scene settle.
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final ready = Stopwatch()..start();
    await waitFor(find.byType(CodeWorldView), const Duration(minutes: 2));
    for (var i = 0; i < 40; i++) {
      boundary.markNeedsPaint();
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    ready.stop();
    report['viewer_ready_seconds'] = ready.elapsed.inMilliseconds / 1000;

    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final rgba = await image.toByteData();
    report['captures'] = {
      'viewer.png': base64Encode(png!.buffer.asUint8List()),
    };
    final stats = FrameStats.of(
      rgba!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
      clear: (r: 245, g: 247, b: 252),
    );
    log('${image.width}x${image.height} $stats');
    expect(
      stats.foregroundLuma,
      greaterThan(20),
      reason: 'the viewer drew almost nothing',
    );

    // Back on the home screen the map is listed, and it was stored.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Recent maps'), findsOneWidget);
    expect(find.textContaining('flutter_scene'), findsWidgets);
    final stored = Directory('${storage.path}/code_maps')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dc3d'));
    expect(stored, hasLength(1));
    report['map_bytes'] = stored.single.lengthSync();
  }, timeout: const Timeout(Duration(minutes: 12)));
}
