// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/code_maps.dart';
import '../../helpers/helpers.dart';

Widget _frame() => Builder(
  builder: (context) => ColoredBox(
    color: context.worldColors.background,
    child: SearchOverlay(map: sampleMap(), onSelect: (_) {}, onClose: () {}),
  ),
);

Future<void> Function(WidgetTester) _typing(String query) => (tester) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
};

void main() {
  group(SearchOverlay, () {
    goldenTest(
      'invites to type',
      fileName: 'search_empty',
      locales: const [Locale('en'), Locale('fr')],
      builder: _frame,
    );

    goldenTest(
      'lists many results with their kind and file',
      fileName: 'search_results',
      locales: const [Locale('en'), Locale('fr')],
      pump: _typing('weather'),
      builder: _frame,
    );

    goldenTest(
      'finds an acronym',
      fileName: 'search_acronym',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      pump: _typing('wac'),
      builder: _frame,
    );

    goldenTest(
      'says when nothing matches',
      fileName: 'search_no_match',
      locales: const [Locale('en'), Locale('fr')],
      pump: _typing('zzzqq'),
      builder: _frame,
    );
  });
}
