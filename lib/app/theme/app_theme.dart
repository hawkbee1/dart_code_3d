import 'package:material_ui/material_ui.dart';

/// The app's light and dark Material 3 themes.
///
/// Minimal on purpose: session 10 (docs/dart_code_3d) builds the full theme
/// (color scheme, text theme, spacing tokens, 3D world colors).
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
    );
  }
}
