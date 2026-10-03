import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(NewAnalysisPage, () {
    testWidgets('says the source choice is coming', (tester) async {
      await tester.pumpApp(const NewAnalysisPage());

      expect(find.text('New analysis'), findsOneWidget);
      expect(find.textContaining('next version'), findsOneWidget);
    });
  });
}
