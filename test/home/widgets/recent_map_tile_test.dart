import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/widgets/recent_map_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RecentMapTile, () {
    late List<String> calls;

    setUp(() => calls = []);

    CodeMapSummary summary(SourceDescriptor source, {String name = 'app'}) =>
        CodeMapSummary(
          id: 'x',
          name: name,
          source: source,
          createdAt: DateTime.utc(2026, 10, 4, 12),
          nodeCount: 1234,
          linkCount: 10,
          sizeBytes: 100,
        );

    Future<void> pump(
      WidgetTester tester,
      CodeMapSummary map, {
      ExportMode mode = ExportMode.saveFile,
    }) => tester.pumpApp(
      Scaffold(
        body: RecentMapTile(
          summary: map,
          exportMode: mode,
          onOpen: () => calls.add('open'),
          onExport: () => calls.add('export'),
          onDelete: () => calls.add('delete'),
        ),
      ),
    );

    testWidgets('writes a git source without its scheme, with the ref', (
      tester,
    ) async {
      await pump(
        tester,
        summary(const GitDescriptor(url: 'https://github.com/o/r', ref: 'dev')),
      );

      expect(find.textContaining('github.com/o/r @ dev'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    });

    testWidgets('writes a git source without a ref as its URL alone', (
      tester,
    ) async {
      await pump(
        tester,
        summary(const GitDescriptor(url: 'http://example.com/o/r')),
      );

      expect(find.text('example.com/o/r'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('names a folder and a zip file', (tester) async {
      await pump(
        tester,
        summary(const LocalFolderDescriptor(name: 'weather_app')),
      );
      expect(find.textContaining('Folder · weather_app'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);

      await pump(tester, summary(const ZipDescriptor(fileName: 'app.zip')));
      expect(find.textContaining('Zip · app.zip'), findsOneWidget);
      expect(find.byIcon(Icons.folder_zip_outlined), findsOneWidget);
    });

    testWidgets('says the number of spheres and the date', (tester) async {
      await pump(tester, summary(const ZipDescriptor(fileName: 'a.zip')));

      expect(
        find.textContaining('1,234 spheres · Oct 4, 2026'),
        findsOneWidget,
      );
    });

    testWidgets('opens on tap', (tester) async {
      await pump(tester, summary(const ZipDescriptor(fileName: 'a.zip')));

      await tester.tap(find.text('app'));

      expect(calls, ['open']);
    });

    testWidgets('has a menu with open, export and delete', (tester) async {
      await pump(tester, summary(const ZipDescriptor(fileName: 'a.zip')));

      for (final (entry, call) in [
        ('Open', 'open'),
        ('Export', 'export'),
        ('Delete', 'delete'),
      ]) {
        await tester.tap(find.byTooltip('Actions for app'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(entry).last);
        await tester.pump();
        expect(calls.last, call);
      }
    });

    testWidgets('names the export of a phone Share', (tester) async {
      await pump(
        tester,
        summary(const ZipDescriptor(fileName: 'a.zip')),
        mode: ExportMode.share,
      );

      await tester.tap(find.byTooltip('Actions for app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('keeps a very long name on one line', (tester) async {
      await pump(
        tester,
        summary(const ZipDescriptor(fileName: 'a.zip'), name: 'x' * 300),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
