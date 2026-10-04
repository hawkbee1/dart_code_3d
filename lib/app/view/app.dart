import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

class App extends StatelessWidget {
  new({
    required this.settingsRepository,
    required this.codeMapRepository,
    this.flavor = AppFlavor.production,
    String initialLocation = '/',
    GoRouter? router,
    PlatformCapabilities? capabilities,
    FileDialogs? fileDialogs,
    FileExporter? fileExporter,
    super.key,
  }) : router =
           router ??
           GoRouter(routes: $appRoutes, initialLocation: initialLocation),
       capabilities = capabilities ?? PlatformCapabilities.current,
       fileDialogs = fileDialogs ?? const FilePickerDialogs(),
       fileExporter = fileExporter ?? PlatformFileExporter();

  final SettingsRepository settingsRepository;

  final CodeMapRepository codeMapRepository;

  /// The build flavor: development adds debugging tools.
  final AppFlavor flavor;

  /// The router; injectable for tests.
  final GoRouter router;

  /// What this platform can do (the running platform's by default).
  final PlatformCapabilities capabilities;

  /// The dialogs that pick files and folders (the native ones by default).
  final FileDialogs fileDialogs;

  /// Shares, saves or downloads a map (the platform's by default).
  final FileExporter fileExporter;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: settingsRepository),
        RepositoryProvider.value(value: codeMapRepository),
        RepositoryProvider.value(value: flavor),
        RepositoryProvider.value(value: capabilities),
        RepositoryProvider<FileDialogs>.value(value: fileDialogs),
        RepositoryProvider<FileExporter>.value(value: fileExporter),
      ],
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
