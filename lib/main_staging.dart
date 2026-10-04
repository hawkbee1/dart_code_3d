import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/bootstrap.dart';
import 'package:settings_repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  await bootstrap(
    () => App(
      settingsRepository: SettingsRepository(
        preferences: SharedPreferencesAsync(),
      ),
    ),
  );
}
