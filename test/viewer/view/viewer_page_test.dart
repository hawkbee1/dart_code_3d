import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
import 'package:settings_repository/settings_repository.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';
import '../../helpers/settings.dart';
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
        settingsBloc: settingsBlocWith(),
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

    testWidgets('explains a stored map that is gone', (tester) async {
      final router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);
      await tester.pumpApp(
        viewerViewWith(
          viewerBlocWith(
            const ViewerFailure('', kind: ViewerFailureKind.missing),
          ),
        ),
        router: router,
      );

      expect(find.text('This map is not stored any more'), findsOneWidget);
      expect(
        find.textContaining('maps are kept in memory only'),
        findsOneWidget,
      );
      expect(find.text('This file is not a code map'), findsNothing);

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

    testWidgets('the controls button and the ? key show the help', (
      tester,
    ) async {
      await tester.pumpApp(
        viewerViewWith(viewerBlocWith(ViewerReady(map: map))),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Flying controls'));
      await tester.pumpAndSettle();
      expect(find.text('Back to the start'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '?');
      await tester.pumpAndSettle();
      expect(find.text('Back to the start'), findsOneWidget);
    });

    testWidgets('reports the sphere the camera flies into', (tester) async {
      final bloc = viewerBlocWith(ViewerReady(map: map));
      late FlyNavigator navigator;
      await tester.pumpApp(
        viewerViewWith(
          bloc,
          sceneBuilder: (context, world, flyNavigator) {
            navigator = flyNavigator;
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pump();

      // The start pose looks at main(): flying forward enters it.
      navigator.input.forward = true;
      for (var i = 0; i < 300 && navigator.container == null; i++) {
        navigator.step(1 / 30);
      }

      verify(() => bloc.add(const ViewerContainerChanged('main'))).called(1);
    });

    group('selecting', () {
      late MockViewerBloc bloc;
      late FlyNavigator navigator;
      late CodeWorld world;
      late CodeMap sample;

      setUp(() => sample = sampleMap());

      Widget view(
        ViewerReady state, {
        TouchControlsMode touchControls = TouchControlsMode.never,
      }) {
        bloc = viewerBlocWith(state);
        return viewerViewWith(
          bloc,
          touchControls: touchControls,
          sceneBuilder: (context, codeWorld, flyNavigator) {
            world = codeWorld;
            navigator = flyNavigator;
            return const SizedBox.expand();
          },
        );
      }

      void phone(WidgetTester tester) {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      /// Where [id] is on the screen, in the 3D area.
      Offset on(WidgetTester tester, String id) {
        final rect = tester.getRect(find.byType(FlyControls));
        return rect.topLeft +
            navigator.viewCamera(rect.size).project(world.positions[id]!)!;
      }

      String idOf(String name) =>
          sample.graph.nodes.values.firstWhere((n) => n.name == name).id;

      group('the panel', () {
        testWidgets('is a side sheet on a wide screen', (tester) async {
          await tester.pumpApp(
            view(ViewerReady(map: nestedMap(), selectedId: 'A')),
          );
          await tester.pump();

          final panel = find.byType(InfoPanel);
          expect(panel, findsOneWidget);
          expect(tester.getSize(panel).width, 360);
          expect(tester.getTopRight(panel).dx, 800);
          expect(find.text('Class'), findsOneWidget);
        });

        testWidgets('is a bottom sheet on a phone', (tester) async {
          phone(tester);
          await tester.pumpApp(
            view(ViewerReady(map: nestedMap(), selectedId: 'A')),
          );
          await tester.pump();

          final panel = find.byType(InfoPanel);
          expect(tester.getSize(panel).width, 390);
          expect(tester.getBottomLeft(panel).dy, 844);
          expect(tester.getSize(panel).height, lessThanOrEqualTo(420));
        });

        testWidgets('is not there without a selection', (tester) async {
          await tester.pumpApp(view(ViewerReady(map: nestedMap())));
          await tester.pump();

          expect(find.byType(InfoPanel), findsNothing);
        });

        testWidgets('follows the selection', (tester) async {
          final map = nestedMap();
          final first = ViewerReady(map: map, selectedId: 'A');
          // The mock bloc has to be set up before the first listener.
          final changing = viewerBlocWith(first);
          whenListen(
            changing,
            Stream.value(ViewerReady(map: map, selectedId: 'pkg')),
            initialState: first,
          );

          await tester.pumpApp(
            viewerViewWith(
              changing,
              sceneBuilder: (context, codeWorld, flyNavigator) =>
                  const SizedBox.expand(),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text('External package'), findsOneWidget);
          expect(find.text('Class'), findsNothing);
        });

        testWidgets('is kept while the page rebuilds', (tester) async {
          await tester.pumpApp(
            view(ViewerReady(map: nestedMap(), selectedId: 'A')),
          );
          await tester.pump();

          // Opening the search rebuilds the page: same selection, same map.
          await tester.tap(find.byTooltip('Search (/)'));
          await tester.pump();

          expect(find.byType(InfoPanel), findsOneWidget);
          expect(find.byType(SearchOverlay), findsOneWidget);
        });

        testWidgets('keeps the HUD clear of a side sheet', (tester) async {
          await tester.pumpApp(
            view(ViewerReady(map: nestedMap(), selectedId: 'A')),
          );
          await tester.pump();

          expect(
            tester.getTopRight(find.byType(HudToolbar)).dx,
            lessThanOrEqualTo(800 - 360),
          );
        });

        testWidgets('hides the touch controls only under a bottom sheet', (
          tester,
        ) async {
          phone(tester);
          await tester.pumpApp(
            view(
              ViewerReady(map: nestedMap()),
              touchControls: TouchControlsMode.always,
            ),
          );
          await tester.pump();
          expect(find.byType(Trackball), findsOneWidget);

          await tester.pumpApp(
            view(
              ViewerReady(map: nestedMap(), selectedId: 'A'),
              touchControls: TouchControlsMode.always,
            ),
          );
          await tester.pump();
          expect(find.byType(Trackball), findsNothing);
        });

        testWidgets('keeps the touch controls beside a side sheet', (
          tester,
        ) async {
          await tester.pumpApp(
            view(
              ViewerReady(map: nestedMap(), selectedId: 'A'),
              touchControls: TouchControlsMode.always,
            ),
          );
          await tester.pump();

          expect(find.byType(Trackball), findsOneWidget);
        });
      });

      group('in the 3D view', () {
        testWidgets('a tap on a sphere selects it', (tester) async {
          await tester.pumpApp(view(ViewerReady(map: worldMap())));
          await tester.pump();

          await tester.tapAt(on(tester, 'main'));

          verify(() => bloc.add(const ViewerNodeSelected('main'))).called(1);
        });

        testWidgets('a tap on empty space deselects', (tester) async {
          await tester.pumpApp(
            view(ViewerReady(map: worldMap(), selectedId: 'A')),
          );
          await tester.pump();

          await tester.tapAt(const Offset(30, 400));

          verify(() => bloc.add(const ViewerNodeSelected(null))).called(1);
        });

        testWidgets('Esc deselects', (tester) async {
          await tester.pumpApp(
            view(ViewerReady(map: worldMap(), selectedId: 'A')),
          );
          await tester.pump();

          await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

          verify(() => bloc.add(const ViewerNodeSelected(null))).called(1);
        });

        testWidgets('Enter selects what is under the crosshair', (
          tester,
        ) async {
          await tester.pumpApp(view(ViewerReady(map: worldMap())));
          await tester.pump();

          await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

          verify(() => bloc.add(const ViewerNodeSelected('main'))).called(1);
        });
      });

      group('the panel actions', () {
        Future<void> pumpSelected(
          WidgetTester tester,
          String id, {
          bool disableAnimations = true,
        }) async {
          await tester.pumpApp(
            view(ViewerReady(map: nestedMap(), selectedId: id)),
            disableAnimations: disableAnimations,
          );
          await tester.pump();
        }

        testWidgets('fly to flies to the node', (tester) async {
          await pumpSelected(tester, 'A', disableAnimations: false);

          await tester.tap(find.text('Fly to'));

          expect(navigator.isFlying, isTrue);
        });

        testWidgets('fly to jumps there without animations', (tester) async {
          await pumpSelected(tester, 'A');

          await tester.tap(find.text('Fly to'));

          expect(navigator.isFlying, isFalse);
          // Facing it from four radii.
          expect(
            navigator.position.distanceTo(world.positions['A']!),
            closeTo(12, 1e-2),
          );
        });

        testWidgets('enter goes inside the node', (tester) async {
          await pumpSelected(tester, 'A');

          await tester.tap(find.text('Enter'));

          expect(navigator.container, 'A');
        });

        testWidgets('there is nothing to enter in a method', (tester) async {
          await pumpSelected(tester, 'A.m');

          expect(find.text('Enter'), findsNothing);
        });

        testWidgets('show only its links asks for the focus', (tester) async {
          await pumpSelected(tester, 'A');

          await tester.tap(find.text('Show only its links'));

          verify(() => bloc.add(const ViewerFocusToggled())).called(1);
        });

        testWidgets('close deselects', (tester) async {
          await pumpSelected(tester, 'A');

          await tester.tap(find.byTooltip('Close'));

          verify(() => bloc.add(const ViewerNodeSelected(null))).called(1);
        });

        testWidgets('copy path copies the location and says so', (
          tester,
        ) async {
          final copied = <String>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied.add(
                  (call.arguments as Map<Object?, Object?>)['text']! as String,
                );
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          await tester.pumpApp(
            view(ViewerReady(map: sample, selectedId: idOf('WeatherCache'))),
          );
          await tester.pump();

          await tester.tap(find.text('Copy path'));
          await tester.pump();

          expect(
            copied.single,
            startsWith('lib/weather/data/weather_cache.dart:9'),
          );
          expect(find.textContaining('Copied: lib/weather'), findsOneWidget);
        });
      });

      group('the search', () {
        Future<void> pumpSample(WidgetTester tester) async {
          await tester.pumpApp(
            view(ViewerReady(map: sample)),
            disableAnimations: true,
          );
          await tester.pump();
        }

        testWidgets('opens from the toolbar, and closes with its button', (
          tester,
        ) async {
          await pumpSample(tester);
          expect(find.byType(SearchOverlay), findsNothing);

          await tester.tap(find.byTooltip('Search (/)'));
          await tester.pump();
          expect(find.byType(SearchOverlay), findsOneWidget);

          await tester.tap(find.byTooltip('Close search'));
          await tester.pump();
          expect(find.byType(SearchOverlay), findsNothing);
        });

        testWidgets('opens with / and with Ctrl+F', (tester) async {
          await pumpSample(tester);

          await tester.sendKeyDownEvent(
            LogicalKeyboardKey.slash,
            character: '/',
          );
          await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
          await tester.pump();
          expect(find.byType(SearchOverlay), findsOneWidget);

          await tester.tap(find.byTooltip('Close search'));
          await tester.pump();
          await tester.tap(find.byType(FlyControls));
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pump();
          expect(find.byType(SearchOverlay), findsOneWidget);
        });

        testWidgets('Esc closes it and the keys fly again', (tester) async {
          await pumpSample(tester);
          await tester.tap(find.byTooltip('Search (/)'));
          await tester.pump();

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(find.byType(SearchOverlay), findsNothing);

          // Back to the 3D area: the arrow keys fly again, without a click.
          await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
          expect(navigator.input.forward, isTrue);
        });

        testWidgets('picking a result selects it and flies there', (
          tester,
        ) async {
          await pumpSample(tester);
          await tester.tap(find.byTooltip('Search (/)'));
          await tester.pump();

          await tester.enterText(find.byType(TextField), 'weathercache');
          await tester.pump();
          await tester.tap(find.text('WeatherCache').first);
          await tester.pump();

          verify(() => bloc.add(ViewerNodeSelected(idOf('WeatherCache'))))
              .called(1);
          expect(find.byType(SearchOverlay), findsNothing);
          // The target is inside its class: the camera ends up facing it.
          expect(
            navigator.container,
            sample.graph.nodes[idOf('WeatherCache')]!.parentId,
          );
        });
      });

      group('the labels', () {
        testWidgets('the toolbar button shows or hides them', (tester) async {
          await tester.pumpApp(view(ViewerReady(map: worldMap())));
          await tester.pump();

          await tester.tap(find.byTooltip('Labels (L)'));

          verify(() => bloc.add(const ViewerLabelsToggled())).called(1);
        });

        testWidgets('the L key does too', (tester) async {
          await tester.pumpApp(view(ViewerReady(map: worldMap())));
          await tester.pump();

          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);

          verify(() => bloc.add(const ViewerLabelsToggled())).called(1);
        });

        testWidgets('are drawn only while on', (tester) async {
          await tester.pumpApp(view(ViewerReady(map: worldMap())));
          await tester.pump();
          expect(find.byType(LabelsLayer), findsOneWidget);

          await tester.pumpApp(
            view(ViewerReady(map: worldMap(), labelsOn: false)),
          );
          await tester.pump();
          expect(find.byType(LabelsLayer), findsNothing);
        });
      });

      group('the minimap', () {
        testWidgets('is open on a wide screen', (tester) async {
          await tester.pumpApp(view(ViewerReady(map: nestedMap())));
          await tester.pump();

          expect(find.byTooltip('Hide the map'), findsOneWidget);
        });

        testWidgets('starts collapsed on a phone', (tester) async {
          phone(tester);
          await tester.pumpApp(view(ViewerReady(map: nestedMap())));
          await tester.pump();

          expect(find.byTooltip('Show the map'), findsOneWidget);
        });

        testWidgets('a tap on a sphere selects it and flies there', (
          tester,
        ) async {
          final map = nestedMap();
          await tester.pumpApp(view(ViewerReady(map: map)));
          await tester.pump();
          final positions = cachedWorldPositions(map);
          final projection = MinimapProjection.fit([
            for (final node in map.graph.topLevel)
              (
                id: node.id,
                center: positions[node.id]!,
                radius: map.placements[node.id]!.radius,
              ),
          ], const Size.square(176));
          final mapArea = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size == const Size.square(176),
          );

          await tester.tapAt(
            tester.getTopLeft(mapArea) + projection.toMap(positions['C']!),
          );

          verify(() => bloc.add(const ViewerNodeSelected('C'))).called(1);
          expect(navigator.isFlying, isTrue);
        });
      });
    });

    group('inside a sphere', () {
      late MockViewerBloc bloc;
      late FlyNavigator navigator;
      late CodeWorld world;

      Widget view(ViewerReady state) {
        bloc = viewerBlocWith(state);
        return viewerViewWith(
          bloc,
          sceneBuilder: (context, codeWorld, flyNavigator) {
            world = codeWorld;
            navigator = flyNavigator;
            return const SizedBox.expand();
          },
        );
      }

      testWidgets('draws what the visible world holds', (tester) async {
        final state = ViewerReady(
          map: nestedMap(),
          currentContainerId: 'A',
          viewMode: ViewMode.window,
        );
        await tester.pumpApp(view(state));
        await tester.pump();

        expect(world.containerId, 'A');
        expect(world.instanceCount, state.visible.visibleSpheres.length);
        expect(world.content.shells.single.opacity, windowShellOpacity);
      });

      testWidgets('shows the path, the view toggle and the legend', (
        tester,
      ) async {
        await tester.pumpApp(
          view(ViewerReady(map: nestedMap(), currentContainerId: 'A')),
        );
        await tester.pump();

        expect(find.text('World'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('Inside'), findsOneWidget);
        expect(find.text('Calls'), findsOneWidget);
      });

      testWidgets('the toggle and the V key switch the view mode', (
        tester,
      ) async {
        await tester.pumpApp(
          view(ViewerReady(map: nestedMap(), currentContainerId: 'A')),
        );
        await tester.pump();

        await tester.tap(find.text('Inside'));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);

        verify(() => bloc.add(const ViewerViewModeToggled())).called(2);
      });

      testWidgets('the V key does nothing at the world', (tester) async {
        await tester.pumpApp(view(ViewerReady(map: nestedMap())));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);

        verifyNever(() => bloc.add(const ViewerViewModeToggled()));
      });

      testWidgets('legend chips show and hide link kinds', (tester) async {
        await tester.pumpApp(view(ViewerReady(map: nestedMap())));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilterChip, 'Imports'));

        verify(() => bloc.add(const ViewerLinkKindToggled(LinkKind.import)))
            .called(1);
      });

      testWidgets('a crumb flies the camera out to that level', (tester) async {
        await tester.pumpApp(
          view(ViewerReady(map: nestedMap(), currentContainerId: 'A.B')),
        );
        await tester.pump();
        // The camera starts at the world: put it inside A.B first.
        navigator.flyTo(
          exitPose(
            world: world,
            target: 'A.B',
            from: Vector3(0, 0, 9),
            current: null,
          ),
          animate: false,
        );
        expect(navigator.container, 'A.B');

        await tester.tap(find.widgetWithText(TextButton, 'A'));

        expect(navigator.isFlying, isTrue);
        for (var i = 0; i < 40; i++) {
          navigator.step(1 / 30);
        }
        expect(navigator.isFlying, isFalse);
        expect(navigator.container, 'A');
      });

      testWidgets('crumbs jump when animations are disabled', (tester) async {
        await tester.pumpApp(
          view(ViewerReady(map: nestedMap(), currentContainerId: 'A')),
          disableAnimations: true,
        );
        await tester.pump();
        navigator.flyTo(
          exitPose(
            world: world,
            target: 'A',
            from: Vector3(0, 0, 9),
            current: null,
          ),
          animate: false,
        );

        await tester.tap(find.widgetWithText(TextButton, 'World'));

        expect(navigator.isFlying, isFalse);
        expect(navigator.container, isNull);
      });
    });

    testWidgets('uses flutter_scene by default', (tester) async {
      const view = ViewerView();

      expect(view.initialize, isNull);
      expect(view.sceneBuilder, isNull);
    });
  });
}
