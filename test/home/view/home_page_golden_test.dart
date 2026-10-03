// goldenTest tags every test with TestTag.golden.

import 'package:dart_code_3d/home/home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(HomePage, () {
    goldenTest(
      'shows the empty state with the ways to start',
      fileName: 'home_empty',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => const HomePage(),
    );

    goldenTest(
      'stays readable with large text',
      fileName: 'home_empty',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      textScale: 2,
      builder: () => const HomePage(),
    );
  });
}
