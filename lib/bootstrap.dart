import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:code_source_client/code_source_client.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/app/bloc_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:settings_repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the app of [flavor] with its real repositories: maps are kept in
/// files on native platforms and in memory on the web. [initialLocation] is
/// the first route (the home screen by default).
Future<App> buildApp(AppFlavor flavor, {String initialLocation = '/'}) async =>
    App(
      settingsRepository: SettingsRepository(
        preferences: SharedPreferencesAsync(),
      ),
      codeMapRepository: CodeMapRepository(
        sourceClient: CodeSourceClient(),
        store: await createCodeMapStore(),
      ),
      flavor: flavor,
      initialLocation: initialLocation,
    );

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  // Plugins (shared_preferences, flutter_scene) need the binding first.
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // Add cross-flavor configuration here

  runApp(await builder());
}
