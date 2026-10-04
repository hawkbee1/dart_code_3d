import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] inside the app's real themes and localizations, with an
  /// optional [settingsBloc], mock [router], [textScale],
  /// [disableAnimations] and [flavor]. The app's services are provided when
  /// given: the [repository], file [dialogs], [exporter] and [capabilities]
  /// (a desktop's by default; the dialogs and exporter are inert).
  Future<void> pumpApp(
    Widget widget, {
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('en'),
    SettingsBloc? settingsBloc,
    GoRouter? router,
    double textScale = 1,
    bool disableAnimations = false,
    AppFlavor flavor = AppFlavor.production,
    CodeMapRepository? repository,
    FileDialogs? dialogs,
    FileExporter? exporter,
    PlatformCapabilities capabilities = PlatformCapabilities.desktop,
  }) {
    Widget child = MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: flavor),
        RepositoryProvider.value(value: capabilities),
        if (repository != null) RepositoryProvider.value(value: repository),
        // The real ones when a test does not care: nothing calls them.
        RepositoryProvider<FileDialogs>.value(
          value: dialogs ?? const FilePickerDialogs(),
        ),
        RepositoryProvider<FileExporter>.value(
          value: exporter ?? PlatformFileExporter(),
        ),
      ],
      child: widget,
    );
    if (router != null) {
      child = InheritedGoRouter(goRouter: router, child: child);
    }
    if (settingsBloc != null) {
      child = BlocProvider.value(value: settingsBloc, child: child);
    }
    return pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: app!,
        ),
        home: child,
      ),
    );
  }
}
