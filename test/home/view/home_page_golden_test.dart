// goldenTest tags every test with TestTag.golden.

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(HomePage, () {
    /// Lets the cubit read the maps, then draws them.
    Future<void> loaded(WidgetTester tester) => tester.pump();

    goldenTest(
      'shows the empty state with the ways to start',
      fileName: 'home_empty',
      locales: const [Locale('en'), Locale('fr')],
      repository: repositoryWith,
      pump: loaded,
      builder: () => const HomePage(),
    );

    goldenTest(
      'stays readable with large text',
      fileName: 'home_empty',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      textScale: 2,
      repository: repositoryWith,
      pump: loaded,
      builder: () => const HomePage(),
    );

    goldenTest(
      'lists the recent maps, newest first',
      fileName: 'home_recent',
      locales: const [Locale('en'), Locale('fr')],
      repository: () => repositoryWith(maps: recentSummaries()),
      pump: loaded,
      builder: () => const HomePage(),
    );

    goldenTest(
      'keeps the recent maps readable with large text',
      fileName: 'home_recent',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      textScale: 2,
      repository: () => repositoryWith(maps: recentSummaries()),
      pump: loaded,
      builder: () => const HomePage(),
    );

    goldenTest(
      'tells a browser that maps live in memory',
      fileName: 'home_web',
      capabilities: PlatformCapabilities.web,
      repository: () =>
          repositoryWith(maps: recentSummaries().take(2).toList()),
      pump: loaded,
      builder: () => const HomePage(),
    );

    goldenTest(
      'tells a browser without any map too',
      fileName: 'home_web_empty',
      devices: const [GoldenDevice.phone],
      themeModes: const [ThemeMode.light],
      capabilities: PlatformCapabilities.web,
      repository: repositoryWith,
      pump: loaded,
      builder: () => const HomePage(),
    );

    goldenTest(
      'says when the maps cannot be read',
      fileName: 'home_load_failed',
      devices: const [GoldenDevice.phone, GoldenDevice.desktop],
      themeModes: const [ThemeMode.light],
      repository: () {
        final repository = repositoryWith();
        when(
          repository.recent,
        ).thenThrow(const BuildFailure(BuildFailureKind.storage, 'disk full'));
        return repository;
      },
      pump: loaded,
      builder: () => const HomePage(),
    );
  });
}
