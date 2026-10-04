import 'dart:async';
import 'dart:typed_data';

import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  group(HomePage, () {
    late GoRouter router;
    late MockFileDialogs dialogs;
    late MockFileExporter exporter;
    late MockCodeMapRepository repository;
    late StreamController<void> changes;
    late List<CodeMapSummary> stored;

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(ExportMode.share);
    });

    setUp(() {
      router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);
      dialogs = MockFileDialogs();
      exporter = MockFileExporter();
      changes = StreamController<void>.broadcast(sync: true);
      stored = recentSummaries();
      repository = repositoryWith(maps: stored, changes: changes.stream);
      // What the real repository does: the list changes, and says so.
      when(() => repository.recent()).thenAnswer((_) async => [...stored]);
      when(() => repository.delete(any())).thenAnswer((invocation) async {
        stored.removeWhere((s) => s.id == invocation.positionalArguments.first);
        changes.add(null);
      });
      when(() => repository.load(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        final name = stored.where((s) => s.id == id).firstOrNull?.name;
        return codeMapFileOf(id: id, name: name);
      });
      when(
        () => exporter.export(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() => changes.close());

    Future<void> pump(
      WidgetTester tester, {
      PlatformCapabilities capabilities = PlatformCapabilities.desktop,
      Locale locale = const Locale('en'),
    }) async {
      tester.view
        ..physicalSize = const Size(900, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const HomePage(),
        repository: repository,
        dialogs: dialogs,
        exporter: exporter,
        capabilities: capabilities,
        router: router,
        locale: locale,
      );
      await tester.pump();
    }

    group('without any map', () {
      setUp(() => stored.clear());

      testWidgets('invites to make one, with the ways to start', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('No code maps yet'), findsOneWidget);
        expect(find.text('New analysis'), findsOneWidget);
        expect(find.text('Open file'), findsOneWidget);
        expect(find.text('Open sample'), findsOneWidget);
        expect(find.text('Recent maps'), findsNothing);
      });
    });

    group('with stored maps', () {
      testWidgets('lists them, newest first, with where they come from', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('Recent maps'), findsOneWidget);
        expect(find.text('No code maps yet'), findsNothing);
        expect(find.text('AltMe @ main'), findsOneWidget);
        expect(find.text('weather_app'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('AltMe @ main')).dy,
          lessThan(tester.getTopLeft(find.text('weather_app')).dy),
        );
        expect(
          find.textContaining('github.com/TalaoDAO/AltMe @ main'),
          findsOneWidget,
        );
        expect(find.textContaining('Folder · weather_app'), findsOneWidget);
        expect(find.textContaining('Zip · my_game.zip'), findsOneWidget);
        expect(
          find.textContaining('11,012 spheres · Oct 4, 2026'),
          findsOneWidget,
        );
      });

      testWidgets('opens a map in the viewer', (tester) async {
        await pump(tester);

        await tester.tap(find.text('AltMe @ main'));

        verify(() => router.go('/viewer?id=6-a')).called(1);
      });

      testWidgets('lists them again when one is saved elsewhere', (
        tester,
      ) async {
        await pump(tester);
        stored.insert(
          0,
          CodeMapSummary(
            id: '7-g',
            name: 'brand_new',
            source: const ZipDescriptor(fileName: 'brand_new.zip'),
            createdAt: DateTime.utc(2026, 10, 5, 12),
            nodeCount: 5,
            linkCount: 1,
            sizeBytes: 100,
          ),
        );

        changes.add(null);
        await tester.pump();

        expect(find.text('brand_new'), findsOneWidget);
      });
    });

    group('while the maps are read', () {
      testWidgets('shows that it is working', (tester) async {
        final gate = Completer<List<CodeMapSummary>>();
        when(() => repository.recent()).thenAnswer((_) => gate.future);

        await pump(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('No code maps yet'), findsNothing);
        expect(find.text('New analysis'), findsOneWidget);
        gate.complete(const []);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('when the store cannot be read', () {
      testWidgets('says so and can try again', (tester) async {
        when(() => repository.recent())
            .thenThrow(const BuildFailure(BuildFailureKind.storage, 'disk'));
        await pump(tester);
        expect(find.text('The recent maps could not be read.'), findsOneWidget);

        when(() => repository.recent()).thenAnswer((_) async => [...stored]);
        await tester.tap(find.text('Try again'));
        await tester.pump();

        expect(find.text('Recent maps'), findsOneWidget);
      });
    });

    group('in a browser', () {
      testWidgets('says that the maps are kept in memory only', (tester) async {
        await pump(tester, capabilities: PlatformCapabilities.web);

        expect(find.textContaining('kept in memory'), findsOneWidget);
      });

      testWidgets('does not say it on a device with storage', (tester) async {
        await pump(tester);

        expect(find.textContaining('kept in memory'), findsNothing);
      });
    });

    group('the ways to start', () {
      for (final (label, location) in [
        ('Settings', '/settings'),
        ('New analysis', '/new-analysis'),
        ('Open sample', '/viewer'),
      ]) {
        testWidgets('"$label" goes to $location', (tester) async {
          await pump(tester);

          await tester.tap(
            label == 'Settings' ? find.byTooltip(label) : find.text(label),
          );

          verify(() => router.go(location)).called(1);
        });
      }

      group('Open file', () {
        final picked = PickedFile(name: 'AltMe.dc3d', bytes: Uint8List(3));

        testWidgets('stores the file and opens it', (tester) async {
          when(dialogs.pickCodeMap).thenAnswer((_) async => picked);
          when(() => repository.importBytes(any(), any()))
              .thenAnswer((_) async => codeMapFileOf(id: '8-h'));
          await pump(tester);

          await tester.tap(find.text('Open file'));
          await tester.pump();

          verify(() => repository.save(any())).called(1);
          verify(() => router.go('/viewer?id=8-h')).called(1);
        });

        testWidgets('stays put when the user cancels', (tester) async {
          when(dialogs.pickCodeMap).thenAnswer((_) async => null);
          await pump(tester);

          await tester.tap(find.text('Open file'));
          await tester.pump();

          verifyNever(() => router.go(any()));
        });

        testWidgets('says when the file is not a code map', (tester) async {
          when(dialogs.pickCodeMap).thenAnswer((_) async => picked);
          when(() => repository.importBytes(any(), any())).thenThrow(
            const BuildFailure(BuildFailureKind.invalidFile, 'newer'),
          );
          await pump(tester);

          await tester.tap(find.text('Open file'));
          await tester.pump();
          await tester.pump();

          expect(
            find.textContaining('Could not open the file.'),
            findsOneWidget,
          );
          expect(find.textContaining('Update the app'), findsOneWidget);
          verifyNever(() => router.go(any()));
        });

        testWidgets('says what failed when it could not be stored', (
          tester,
        ) async {
          when(dialogs.pickCodeMap).thenAnswer((_) async => picked);
          when(() => repository.importBytes(any(), any()))
              .thenAnswer((_) async => codeMapFileOf());
          when(() => repository.save(any()))
              .thenThrow(const BuildFailure(BuildFailureKind.storage, 'disk'));
          await pump(tester);

          await tester.tap(find.text('Open file'));
          await tester.pump();
          await tester.pump();

          expect(find.text('The map could not be stored'), findsOneWidget);
        });
      });
    });

    group('the menu of a map', () {
      Future<void> openMenu(WidgetTester tester, String name) async {
        await tester.tap(find.byTooltip('Actions for $name'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      testWidgets('opens the map', (tester) async {
        await pump(tester);
        await openMenu(tester, 'AltMe @ main');

        await tester.tap(find.text('Open').last);

        verify(() => router.go('/viewer?id=6-a')).called(1);
      });

      testWidgets('exports with a dialog on a desktop', (tester) async {
        when(() => repository.exportForSharing(any()))
            .thenReturn((fileName: 'AltMe.dc3d', bytes: Uint8List(2)));
        await pump(tester);
        await openMenu(tester, 'AltMe @ main');
        expect(find.text('Share'), findsNothing);

        await tester.tap(find.text('Export'));
        await tester.pump();

        verify(
          () => exporter.export(
            fileName: 'AltMe.dc3d',
            bytes: Uint8List(2),
            mode: ExportMode.saveFile,
          ),
        ).called(1);
      });

      testWidgets('says Share on a phone', (tester) async {
        await pump(tester, capabilities: PlatformCapabilities.mobile);
        await openMenu(tester, 'AltMe @ main');

        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Export'), findsNothing);
      });

      testWidgets('says when the export failed', (tester) async {
        when(() => repository.exportForSharing(any()))
            .thenReturn((fileName: 'AltMe.dc3d', bytes: Uint8List(2)));
        when(
          () => exporter.export(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            mode: any(named: 'mode'),
          ),
        ).thenThrow(StateError('no dialog'));
        await pump(tester);
        await openMenu(tester, 'AltMe @ main');

        await tester.tap(find.text('Export'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Could not export the map.'), findsOneWidget);
      });

      testWidgets('deletes the map, and puts it back on Undo', (tester) async {
        await pump(tester);
        await openMenu(tester, 'weather_app');

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('weather_app'), findsNothing);
        expect(find.text('Deleted weather_app'), findsOneWidget);
        verify(() => repository.delete('4-c')).called(1);

        await tester.tap(find.text('Undo'));
        await tester.pump();

        verify(() => repository.save(any())).called(1);
      });
    });

    testWidgets('deletes a map swiped away, with an undo', (tester) async {
      await pump(tester);

      await tester.drag(find.text('weather_app'), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(find.text('weather_app'), findsNothing);
      verify(() => repository.delete('4-c')).called(1);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('meets the tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('speaks French', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Cartes récentes'), findsOneWidget);
      expect(find.text('Nouvelle analyse'), findsOneWidget);
      expect(find.textContaining(RegExp('11.012 sphères')), findsOneWidget);
    });
  });
}
