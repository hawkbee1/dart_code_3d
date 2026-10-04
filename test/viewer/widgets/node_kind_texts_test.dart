import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('node kind texts', () {
    late AppLocalizations l10n;

    Future<void> load(WidgetTester tester, Locale locale) => tester.pumpApp(
      Builder(
        builder: (context) {
          l10n = context.l10n;
          return const SizedBox();
        },
      ),
      locale: locale,
    );

    testWidgets('name every kind of node, in English and French', (
      tester,
    ) async {
      await load(tester, const Locale('en'));
      final english = [
        for (final k in CodeNodeKind.values) l10n.nodeKindLabel(k),
      ];
      await load(tester, const Locale('fr'));
      final french = [
        for (final k in CodeNodeKind.values) l10n.nodeKindLabel(k),
      ];

      expect(english.toSet(), hasLength(CodeNodeKind.values.length));
      expect(french.toSet(), hasLength(CodeNodeKind.values.length));
      expect(english, isNot(french));
      expect(english, contains('Class'));
      expect(french, contains('Classe'));
    });

    testWidgets('name every link resolution, in English and French', (
      tester,
    ) async {
      await load(tester, const Locale('en'));
      final english = [
        for (final r in LinkResolution.values) l10n.resolutionLabel(r),
      ];
      await load(tester, const Locale('fr'));
      final french = [
        for (final r in LinkResolution.values) l10n.resolutionLabel(r),
      ];

      expect(english, ['exact', 'by name', 'ambiguous', 'external']);
      expect(french, ['exact', 'par le nom', 'ambigu', 'externe']);
    });

    test('give each kind an icon', () {
      for (final kind in CodeNodeKind.values) {
        expect(nodeKindIcon(kind), isA<IconData>());
      }
      expect(
        nodeKindIcon(CodeNodeKind.classDecl),
        isNot(nodeKindIcon(CodeNodeKind.method)),
      );
    });
  });
}
