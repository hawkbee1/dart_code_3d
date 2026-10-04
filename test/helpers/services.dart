import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:mocktail/mocktail.dart';

/// A repository test double.
class MockCodeMapRepository extends Mock implements CodeMapRepository;

/// A file dialogs test double.
class MockFileDialogs extends Mock implements FileDialogs;

/// A file exporter test double.
class MockFileExporter extends Mock implements FileExporter;

class _FakeCodeMapFile extends Fake implements CodeMapFile;

/// A repository that lists [maps], never changes and saves anything.
MockCodeMapRepository repositoryWith({
  List<CodeMapSummary> maps = const [],
  Stream<void>? changes,
}) {
  registerFallbackValue(_FakeCodeMapFile());
  final repository = MockCodeMapRepository();
  when(repository.recent).thenAnswer((_) async => maps);
  when(() => repository.changes)
      .thenAnswer((_) => changes ?? const Stream<void>.empty());
  when(() => repository.save(any())).thenAnswer((_) async {});
  when(() => repository.delete(any())).thenAnswer((_) async {});
  return repository;
}

/// Six stored maps with realistic names, newest first (dates at noon UTC, so
/// they read the same in every time zone).
List<CodeMapSummary> recentSummaries() => [
  CodeMapSummary(
    id: '6-a',
    name: 'AltMe @ main',
    source: const GitDescriptor(
      url: 'https://github.com/TalaoDAO/AltMe',
      ref: 'main',
    ),
    createdAt: DateTime.utc(2026, 10, 4, 12),
    nodeCount: 11012,
    linkCount: 7414,
    sizeBytes: 1500000,
  ),
  CodeMapSummary(
    id: '5-b',
    name: 'flutter_scene @ flutter_scene-0.23.0',
    source: const GitDescriptor(
      url: 'https://github.com/bdero/flutter_scene',
      ref: 'flutter_scene-0.23.0',
    ),
    createdAt: DateTime.utc(2026, 10, 3, 12),
    nodeCount: 11050,
    linkCount: 17609,
    sizeBytes: 1640000,
  ),
  CodeMapSummary(
    id: '4-c',
    name: 'weather_app',
    source: const LocalFolderDescriptor(name: 'weather_app'),
    createdAt: DateTime.utc(2026, 10, 1, 12),
    nodeCount: 159,
    linkCount: 109,
    sizeBytes: 22000,
  ),
  CodeMapSummary(
    id: '3-d',
    name: 'very_good_cli',
    source: const GitDescriptor(
      url: 'https://github.com/VeryGoodOpenSource/very_good_cli',
    ),
    createdAt: DateTime.utc(2026, 9, 28, 12),
    nodeCount: 2310,
    linkCount: 3120,
    sizeBytes: 410000,
  ),
  CodeMapSummary(
    id: '2-e',
    name: 'my_game.zip',
    source: const ZipDescriptor(fileName: 'my_game.zip'),
    createdAt: DateTime.utc(2026, 9, 20, 12),
    nodeCount: 845,
    linkCount: 1210,
    sizeBytes: 120000,
  ),
  CodeMapSummary(
    id: '1-f',
    name: 'a_package_with_a_really_long_name_that_has_to_be_cut_somewhere',
    source: const LocalFolderDescriptor(
      name: 'a_package_with_a_really_long_name_that_has_to_be_cut_somewhere',
    ),
    createdAt: DateTime.utc(2026, 8, 2, 12),
    nodeCount: 37,
    linkCount: 12,
    sizeBytes: 5000,
  ),
];
