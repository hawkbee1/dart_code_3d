part of 'settings_bloc.dart';

/// Something the user did on the settings.
sealed class SettingsEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Load the stored settings (once, at app start).
final class SettingsStarted extends SettingsEvent {
  const new();
}

/// The user picked a theme mode.
final class SettingsThemeModeChanged extends SettingsEvent {
  const new(this.themeMode);

  final AppThemeMode themeMode;

  @override
  List<Object?> get props => [themeMode];
}

/// The user changed rule [id] to [value].
final class SettingsRuleChanged extends SettingsEvent {
  const new(this.id, this.value);

  final String id;
  final Object value;

  @override
  List<Object?> get props => [id, value];
}

/// The user restored the default rules.
final class SettingsRulesReset extends SettingsEvent {
  const new();
}
