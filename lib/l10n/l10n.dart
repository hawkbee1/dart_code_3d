import 'package:dart_code_3d/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:dart_code_3d/l10n/failure_texts.dart';
export 'package:dart_code_3d/l10n/gen/app_localizations.dart';

/// The delegates to give `MaterialApp.localizationsDelegates`.
///
/// Use this instead of `AppLocalizations.localizationsDelegates`: the
/// generated list registers `flutter_localizations`' Material and Cupertino
/// delegates, which do not serve the `material_ui` widgets this app uses, so
/// every locale but English would miss its Material strings.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
