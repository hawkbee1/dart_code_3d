import 'dart:async';

import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';
import '../../helpers/viewer.dart';

class _MockCodeMapRepository extends Mock implements CodeMapRepository;

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  group(ViewerPage, () {
    setUpAll(() => registerFallbackValue(Uint8List(0)));

    testWidgets('opens the bundled sample by default', (tester) async {
      final repository = _MockCodeMapRepository();
      // Never completes: the page stays on its loading state.
      when(() => repository.openBytes(any()))
          .thenAnswer((_) => Completer<CodeMap>().future);

      await tester.pumpApp(
        RepositoryProvider<CodeMapRepository>.value(
          value: repository,
          child: const ViewerPage(),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.text('Opening the code map…'), findsOneWidget);
      final bytes =
          verify(() => repository.openBytes(captureAny())).captured.single
              as Uint8List;
      expect(bytes.length, greaterThan(1000));
    });
  });

  group(ViewerView, () {
    late CodeMap map;

    setUp(() => map = worldMap());

    testWidgets('shows progress while the map opens', (tester) async {
      await tester.pumpApp(
        viewerViewWith(viewerBlocWith(const ViewerLoading())),
      );

      expect(find.text('Opening the code map…'), findsOneWidget);
      expect(find.text('dart_code_3D'), findsOneWidget);
    });

    testWidgets('explains a file that is not a code map', (tester) async {
      final router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);
      await tester.pumpApp(
        viewerViewWith(viewerBlocWith(const ViewerFailure('Not gzip.'))),
        router: router,
      );

      expect(find.text('This file is not a code map'), findsOneWidget);
      expect(find.text('Not gzip.'), findsOneWidget);

      await tester.tap(find.text('Back to home'));
      verify(() => router.go('/')).called(1);
    });

    testWidgets('shows the map, its name and its size', (tester) async {
      await tester.pumpApp(
        viewerViewWith(viewerBlocWith(ViewerReady(map: map))),
      );
      await tester.pump();

      expect(find.text('tiny_app'), findsOneWidget);
      expect(find.text('4 spheres · 1 links'), findsOneWidget);
      expect(find.byKey(const ValueKey('scene 3')), findsOneWidget);
    });

    testWidgets('F3 toggles the debug overlay in development', (tester) async {
      await tester.pumpApp(
        viewerViewWith(viewerBlocWith(ViewerReady(map: map))),
        flavor: AppFlavor.development,
      );
      await tester.pump();
      expect(find.byType(DebugOverlay), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      expect(find.byType(DebugOverlay), findsOneWidget);
      expect(find.textContaining('3 spheres'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      expect(find.byType(DebugOverlay), findsNothing);
    });

    testWidgets('F3 does nothing in production', (tester) async {
      await tester.pumpApp(
        viewerViewWith(viewerBlocWith(ViewerReady(map: map))),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();

      expect(find.byType(DebugOverlay), findsNothing);
    });

    testWidgets('uses flutter_scene by default', (tester) async {
      const view = ViewerView();

      expect(view.initialize, isNull);
      expect(view.sceneBuilder, isNull);
    });
  });
}
