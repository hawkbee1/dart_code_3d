import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

class App extends StatelessWidget {
  new({required this.settingsRepository, GoRouter? router, super.key})
    : router = router ?? GoRouter(routes: $appRoutes);

  final SettingsRepository settingsRepository;

  /// The router; injectable for tests.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: settingsRepository,
      child: BlocProvider(
        create: (_) =>
            SettingsBloc(repository: settingsRepository)
              ..add(const SettingsStarted()),
        child: AppView(router: router),
      ),
    );
  }
}

class AppView extends StatelessWidget {
  const new({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsBloc, AppThemeMode>(
      (bloc) => bloc.state.themeMode,
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
