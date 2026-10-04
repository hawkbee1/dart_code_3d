import 'package:dart_code_3d/app/theme/app_spacing.dart';
import 'package:dart_code_3d/app/theme/code_world_colors.dart';
import 'package:material_ui/material_ui.dart';

/// The app's light and dark Material 3 themes: the single source of colors,
/// typography, spacing and 3D world colors.
abstract final class AppTheme {
  /// Seed of the color scheme.
  static const Color seedColor = Color(0xFF3F7FD9);

  /// Font family bundled in `assets/fonts`.
  static const String fontFamily = 'Roboto';

  /// Light theme.
  static final ThemeData light = _build(Brightness.light);

  /// Dark theme.
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(backgroundColor: colorScheme.inversePrimary),
      chipTheme: const ChipThemeData(showCheckmark: false),
      extensions: [
        const AppSpacing(),
        if (brightness == Brightness.light)
          CodeWorldColors.light
        else
          CodeWorldColors.dark,
      ],
    );
  }
}

/// Short access to the theme extensions.
extension AppThemeX on BuildContext {
  /// Spacing tokens.
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;

  /// 3D world colors.
  CodeWorldColors get worldColors =>
      Theme.of(this).extension<CodeWorldColors>()!;
}
