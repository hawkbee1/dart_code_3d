import 'package:code_map_repository/code_map_repository.dart';

/// The store of the web: maps live in memory, and are lost when the page
/// reloads (the home screen says so). IndexedDB is in `future.md`.
Future<CodeMapStore> createCodeMapStore() async => InMemoryCodeMapStore();
