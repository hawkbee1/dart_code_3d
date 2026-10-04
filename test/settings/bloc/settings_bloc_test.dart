import 'package:bloc_test/bloc_test.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository;

void main() {
  group(SettingsBloc, () {
    late SettingsRepository repository;
    final imports = AnalysisRules.defaults().copyWith(
      RuleIds.linksImports,
      true,
    );

    setUpAll(() {
      registerFallbackValue(AnalysisRules.defaults());
      registerFallbackValue(AppThemeMode.system);
    });

    setUp(() {
      repository = _MockSettingsRepository();
      when(() => repository.themeMode())
          .thenAnswer((_) async => AppThemeMode.dark);
      when(() => repository.rules()).thenAnswer((_) async => imports);
      when(() => repository.setThemeMode(any())).thenAnswer((_) async {});
      when(() => repository.setRules(any())).thenAnswer((_) async {});
      when(() => repository.resetRules()).thenAnswer((_) async {});
    });

    SettingsBloc build() => SettingsBloc(repository: repository);

    test('starts loading with the defaults', () {
      expect(build().state, SettingsState());
    });

    blocTest<SettingsBloc, SettingsState>(
      'loads the stored settings',
      build: build,
      act: (bloc) => bloc.add(const SettingsStarted()),
      expect: () => [
        SettingsState(
          status: SettingsStatus.ready,
          themeMode: AppThemeMode.dark,
          rules: imports,
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'changes and stores the theme mode',
      build: build,
      act: (bloc) =>
          bloc.add(const SettingsThemeModeChanged(AppThemeMode.light)),
      expect: () => [SettingsState(themeMode: AppThemeMode.light)],
      verify: (_) =>
          verify(() => repository.setThemeMode(AppThemeMode.light)).called(1),
    );

    blocTest<SettingsBloc, SettingsState>(
      'changes and stores a rule',
      build: build,
      act: (bloc) =>
          bloc.add(const SettingsRuleChanged(RuleIds.linksImports, true)),
      expect: () => [SettingsState(rules: imports)],
      verify: (_) => verify(() => repository.setRules(imports)).called(1),
    );

    blocTest<SettingsBloc, SettingsState>(
      'resets the rules',
      build: build,
      seed: () => SettingsState(rules: imports),
      act: (bloc) => bloc.add(const SettingsRulesReset()),
      expect: () => [SettingsState()],
      verify: (_) => verify(() => repository.resetRules()).called(1),
    );

    test('events and states compare by value', () {
      expect(
        SettingsRuleChanged(RuleIds.dartSdk, ['x'].isNotEmpty),
        SettingsRuleChanged(RuleIds.dartSdk, ['x'].isNotEmpty),
      );
      expect(
        SettingsThemeModeChanged([AppThemeMode.dark].single),
        SettingsThemeModeChanged([AppThemeMode.dark].single),
      );
      expect(const SettingsStarted().props, isEmpty);
    });
  });
}
