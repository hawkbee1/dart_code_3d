import 'package:flutter/widgets.dart';
import 'package:dart_code_3d/l10n/gen/app_localizations.dart';

export 'package:dart_code_3d/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
