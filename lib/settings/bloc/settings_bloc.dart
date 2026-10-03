import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:settings_repository/settings_repository.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Holds the theme mode, the touch controls mode and the engine rules, and
/// persists every change.
///
/// Provided above `MaterialApp`, so the theme mode applies immediately.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  new({required this._repository}) : super(SettingsState()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsThemeModeChanged>(_onThemeModeChanged);
    on<SettingsTouchControlsChanged>(_onTouchControlsChanged);
    on<SettingsRuleChanged>(_onRuleChanged);
    on<SettingsRulesReset>(_onRulesReset);
  }

  final SettingsRepository _repository;

  Future<void> _onStarted(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SettingsStatus.ready,
        themeMode: await _repository.themeMode(),
        touchControls: await _repository.touchControls(),
        rules: await _repository.rules(),
      ),
    );
  }

  Future<void> _onThemeModeChanged(
    SettingsThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(themeMode: event.themeMode));
    await _repository.setThemeMode(event.themeMode);
  }

  Future<void> _onTouchControlsChanged(
    SettingsTouchControlsChanged event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(touchControls: event.mode));
    await _repository.setTouchControls(event.mode);
  }

  Future<void> _onRuleChanged(
    SettingsRuleChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final rules = state.rules.copyWith(event.id, event.value);
    emit(state.copyWith(rules: rules));
    await _repository.setRules(rules);
  }

  Future<void> _onRulesReset(
    SettingsRulesReset event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(rules: AnalysisRules.defaults()));
    await _repository.resetRules();
  }
}
