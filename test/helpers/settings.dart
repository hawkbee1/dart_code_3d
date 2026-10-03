import 'package:bloc_test/bloc_test.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

/// A settings bloc test double.
class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc;

/// A settings bloc test double whose state is [state].
MockSettingsBloc settingsBlocWith([SettingsState? state]) {
  final bloc = MockSettingsBloc();
  when(() => bloc.state)
      .thenReturn(state ?? SettingsState(status: SettingsStatus.ready));
  return bloc;
}

/// Rules with long glob lists, for screenshots.
AnalysisRules rulesWithLongPatterns() =>
    AnalysisRules.defaults().copyWith(RuleIds.generatedPatterns, const [
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/*.mocks.dart',
      'lib/l10n/gen/app_localizations*.dart',
      'packages/very_long_package_name/lib/src/generated/**',
    ]);
