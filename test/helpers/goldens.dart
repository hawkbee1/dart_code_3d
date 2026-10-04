import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'pump_app.dart';
import 'test_tags.dart';

/// The screen sizes every golden is rendered at (logical pixels, DPR 1).
enum GoldenDevice {
  phone(Size(390, 844)),
  tablet(Size(820, 1180)),
  desktop(Size(1440, 900));

  new(this.size);

  /// Logical size of the screen.
  final Size size;
}

/// Registers one golden test per device × theme × locale for a screen.
///
/// Each image is `goldens/<fileName>/<device>_<theme>[_<locale>].png`, next to
/// the calling test file (the locale suffix is omitted for English). Goldens
/// are UX screenshots for humans as much as regression guards, so give
/// [builder] realistic content. Text renders in the real app font, loaded by
/// `test/flutter_test_config.dart`.
///
/// [repository] and [capabilities] stand for the app's services (a desktop's
/// by default).
///
/// [setUp] runs inside each test before pumping, for example to stub a mock.
/// [pump] runs after the first frame, for example to advance a state.
void goldenTest(
  String description, {
  required String fileName,
  required Widget Function() builder,
  Iterable<GoldenDevice> devices = GoldenDevice.values,
  Iterable<ThemeMode> themeModes = const [ThemeMode.light, ThemeMode.dark],
  Iterable<Locale> locales = const [Locale('en')],
  Future<void> Function(WidgetTester tester)? pump,
  SettingsBloc Function()? settingsBloc,
  GoRouter Function()? router,
  CodeMapRepository Function()? repository,
  PlatformCapabilities capabilities = PlatformCapabilities.desktop,
  double textScale = 1,
}) {
  for (final device in devices) {
    for (final themeMode in themeModes) {
      for (final locale in locales) {
        final localeSuffix = locale.languageCode == 'en'
            ? ''
            : '_${locale.languageCode}';
        final scaleSuffix = textScale == 1 ? '' : '_x$textScale';
        final variant =
            '${device.name}_${themeMode.name}$localeSuffix$scaleSuffix';
        testWidgets('$description ($variant)', tags: TestTag.golden, (
          tester,
        ) async {
          tester.view
            ..physicalSize = device.size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpApp(
            builder(),
            themeMode: themeMode,
            locale: locale,
            settingsBloc: settingsBloc?.call(),
            router: router?.call(),
            repository: repository?.call(),
            capabilities: capabilities,
            textScale: textScale,
          );
          await tester.pump();
          if (pump != null) await pump(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$fileName/$variant.png'),
          );
        });
      }
    }
  }
}
