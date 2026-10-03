part of 'settings_bloc.dart';

/// Whether the stored settings are loaded.
enum SettingsStatus {
  /// Reading storage.
  loading,

  /// Ready.
  ready,
}

/// The current settings.
final class SettingsState extends Equatable {
  /// Creates the state; defaults are used until storage is read.
  new({
    this.status = SettingsStatus.loading,
    this.themeMode = AppThemeMode.system,
    AnalysisRules? rules,
  }) : rules = rules ?? AnalysisRules.defaults();

  final SettingsStatus status;
  final AppThemeMode themeMode;
  final AnalysisRules rules;

  SettingsState copyWith({
    SettingsStatus? status,
    AppThemeMode? themeMode,
    AnalysisRules? rules,
  }) => SettingsState(
    status: status ?? this.status,
    themeMode: themeMode ?? this.themeMode,
    rules: rules ?? this.rules,
  );

  @override
  List<Object?> get props => [status, themeMode, rules];
}
