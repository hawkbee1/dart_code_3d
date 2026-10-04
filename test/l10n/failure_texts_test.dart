import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/l10n/gen/app_localizations_en.dart';
import 'package:dart_code_3d/l10n/gen/app_localizations_fr.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FailureTexts', () {
    for (final (language, l10n) in [
      ('English', AppLocalizationsEn()),
      ('French', AppLocalizationsFr()),
    ]) {
      test(
        'says something specific for every $BuildFailureKind in $language',
        () {
          final titles = {
            for (final kind in BuildFailureKind.values) l10n.failureTitle(kind),
          };
          final bodies = {
            for (final kind in BuildFailureKind.values) l10n.failureBody(kind),
          };

          expect(titles, hasLength(BuildFailureKind.values.length));
          expect(bodies, hasLength(BuildFailureKind.values.length));
          expect(titles.every((t) => t.isNotEmpty), isTrue);
          expect(bodies.every((b) => b.isNotEmpty), isTrue);
        },
      );
    }

    test('tells the user that private repositories are not supported', () {
      expect(
        AppLocalizationsEn().failureBody(BuildFailureKind.privateOrMissingRepo),
        contains('Private repositories are not supported yet'),
      );
    });
  });
}
