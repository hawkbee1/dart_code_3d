// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

import '../../helpers/helpers.dart';
import '../../helpers/settings.dart';

/// Scrolls the settings list until [finder] is on screen, as high as
/// possible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder));
  await tester.pumpAndSettle();
}

/// Scrolls the settings list so the first rule of [group] is at the top.
Future<void> _showGroup(WidgetTester tester, RuleGroup group) => _reveal(
  tester,
  find.byKey(ValueKey(RuleCatalog.all.firstWhere((r) => r.group == group).id)),
);

void main() {
  group(SettingsPage, () {
    goldenTest(
      'shows the theme and the first rules',
      fileName: 'settings_top',
      settingsBloc: settingsBlocWith,
      builder: () => const SettingsPage(),
    );

    goldenTest(
      'shows the theme and the first rules in French',
      fileName: 'settings_top',
      locales: const [Locale('fr')],
      settingsBloc: settingsBlocWith,
      builder: () => const SettingsPage(),
    );

    goldenTest(
      'stays readable with large text',
      fileName: 'settings_top',
      devices: const [GoldenDevice.phone],
      textScale: 2,
      settingsBloc: settingsBlocWith,
      builder: () => const SettingsPage(),
    );

    for (final group in RuleGroup.values) {
      goldenTest(
        'shows the ${group.name} rules',
        fileName: 'settings_${group.name}',
        settingsBloc: settingsBlocWith,
        pump: (tester) => _showGroup(tester, group),
        builder: () => const SettingsPage(),
      );
    }

    goldenTest(
      'wraps a long list of glob patterns',
      fileName: 'settings_long_globs',
      themeModes: const [ThemeMode.light],
      settingsBloc: () => settingsBlocWith(
        SettingsState(
          status: SettingsStatus.ready,
          rules: rulesWithLongPatterns(),
        ),
      ),
      pump: (tester) => _showGroup(
        tester,
        RuleCatalog.all
            .firstWhere((r) => r.id == RuleIds.generatedPatterns)
            .group,
      ),
      builder: () => const SettingsPage(),
    );

    goldenTest(
      'explains an option that is coming later',
      fileName: 'settings_coming_later',
      locales: const [Locale('en'), Locale('fr')],
      settingsBloc: settingsBlocWith,
      pump: (tester) async {
        final rule = find.byKey(
          ValueKey(
            RuleCatalog.all
                .whereType<EnumParameter>()
                .firstWhere((r) => r.options.any((o) => !o.enabled))
                .id,
          ),
        );
        await _reveal(tester, rule);
        // Disabled options are drawn at half opacity.
        await tester.tap(
          find
              .descendant(
                of: find.descendant(
                  of: rule,
                  matching: find.byWidgetPredicate(
                    (w) => w is Opacity && w.opacity == 0.5,
                  ),
                ),
                matching: find.byType(ChoiceChip),
              )
              .first,
        );
        await tester.pumpAndSettle();
      },
      builder: () => const SettingsPage(),
    );

    goldenTest(
      'asks before resetting the rules',
      fileName: 'settings_reset_dialog',
      settingsBloc: settingsBlocWith,
      pump: (tester) async {
        await _reveal(tester, find.byIcon(Icons.restart_alt));
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();
      },
      builder: () => const SettingsPage(),
    );
  });
}
