import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/helpers.dart';

void main() {
  group(App, () {
    late SettingsRepository repository;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      repository = SettingsRepository(preferences: SharedPreferencesAsync());
    });

    testWidgets('starts on the home screen and loads the settings', (
      tester,
    ) async {
      await repository.setThemeMode(AppThemeMode.dark);

      await tester.pumpWidget(
        App(
          settingsRepository: repository,
          codeMapRepository: repositoryWith(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('provides what the screens need from the platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(
          settingsRepository: repository,
          codeMapRepository: repositoryWith(),
          capabilities: PlatformCapabilities.web,
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomePage));
      expect(context.read<PlatformCapabilities>(), PlatformCapabilities.web);
      expect(context.read<FileDialogs>(), isA<FilePickerDialogs>());
      expect(context.read<FileExporter>(), isA<PlatformFileExporter>());
    });

    testWidgets('uses the platform it runs on by default', (tester) async {
      await tester.pumpWidget(
        App(
          settingsRepository: repository,
          codeMapRepository: repositoryWith(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.element(find.byType(HomePage)).read<PlatformCapabilities>(),
        PlatformCapabilities.current,
      );
    });

    testWidgets('applies a theme change immediately', (tester) async {
      await tester.pumpWidget(
        App(
          settingsRepository: repository,
          codeMapRepository: repositoryWith(),
        ),
      );
      await tester.pumpAndSettle();

      for (final (mode, expected) in [
        (AppThemeMode.light, ThemeMode.light),
        (AppThemeMode.system, ThemeMode.system),
      ]) {
        tester
            .element(find.byType(HomePage))
            .read<SettingsBloc>()
            .add(SettingsThemeModeChanged(mode));
        await tester.pumpAndSettle();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          expected,
        );
      }
      expect(await repository.themeMode(), AppThemeMode.system);
    });

    testWidgets('keeps the theme after a restart', (tester) async {
      await tester.pumpWidget(
        App(
          settingsRepository: repository,
          codeMapRepository: repositoryWith(),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .element(find.byType(HomePage))
          .read<SettingsBloc>()
          .add(const SettingsThemeModeChanged(AppThemeMode.dark));
      await tester.pumpAndSettle();

      // A new app with a new repository on the same store.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        App(
          codeMapRepository: repositoryWith(),
          settingsRepository: SettingsRepository(
            preferences: SharedPreferencesAsync(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });
  });
}
