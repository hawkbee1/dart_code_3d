import 'package:dart_code_3d/home/widgets/web_storage_notice.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(WebStorageNotice, () {
    testWidgets('says that maps are lost on reload and can be exported', (
      tester,
    ) async {
      await tester.pumpApp(const WebStorageNotice());

      expect(find.textContaining('kept in memory'), findsOneWidget);
      expect(find.textContaining('Export a map to keep it'), findsOneWidget);
    });

    testWidgets('speaks French', (tester) async {
      await tester.pumpApp(
        const WebStorageNotice(),
        locale: const Locale('fr'),
      );

      expect(find.textContaining('Exportez une carte'), findsOneWidget);
    });
  });
}
