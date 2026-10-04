import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/code_maps.dart';

CodeMap _searchMap() {
  const nodes = <(String, String, String, CodeNodeKind, String?)>[
    ('user', 'User', 'User', CodeNodeKind.classDecl, 'lib/user.dart'),
    (
      'repo',
      'UserRepository',
      'UserRepository',
      CodeNodeKind.classDecl,
      'lib/user_repository.dart',
    ),
    (
      'save',
      'save',
      'UserRepository.save',
      CodeNodeKind.method,
      'lib/user_repository.dart',
    ),
    (
      'cached',
      'CachedUserRepository',
      'CachedUserRepository',
      CodeNodeKind.classDecl,
      'lib/cached.dart',
    ),
    ('name', 'userName', 'userName', CodeNodeKind.function, 'lib/names.dart'),
    ('weather', 'Weather', 'Weather', CodeNodeKind.classDecl, 'lib/w.dart'),
    (
      'cache',
      'WeatherCache',
      'WeatherCache',
      CodeNodeKind.classDecl,
      'lib/w.dart',
    ),
    (
      'client',
      'WeatherApiClient',
      'WeatherApiClient',
      CodeNodeKind.classDecl,
      'lib/w.dart',
    ),
    ('http', 'http', 'http', CodeNodeKind.externalPackage, null),
  ];
  return CodeMap(
    graph: CodeGraph(
      project: ProjectInfo(
        generator: 'test',
        source: const LocalFolderDescriptor(name: 'search'),
        createdAt: DateTime.utc(2026, 10, 4),
      ),
      nodes: {
        for (final (id, name, qualified, kind, file) in nodes)
          id: CodeNode(
            id: id,
            kind: kind,
            name: name,
            qualifiedName: qualified,
            location: file == null
                ? null
                : SourceLocation(filePath: file, startLine: 1, endLine: 9),
          ),
      },
    ),
    placements: {
      for (final (id, _, _, _, _) in nodes)
        id: const Placement(x: 0, y: 0, z: 0, radius: 1),
    },
  );
}

void main() {
  group(SearchIndex, () {
    late SearchIndex index;

    setUp(() => index = SearchIndex(_searchMap()));

    List<String> ids(String query, {int limit = 30}) => [
      for (final r in index.search(query, limit: limit)) r.id,
    ];

    test('finds nothing for an empty or blank query', () {
      expect(index.search(''), isEmpty);
      expect(index.search('   '), isEmpty);
    });

    test('finds nothing when no letters of the query fit', () {
      expect(ids('xyz'), isEmpty);
    });

    test('ranks the exact name first, then names that start with it', () {
      expect(ids('user').take(3), ['user', 'name', 'repo']);
    });

    test('then names with a word that starts with it', () {
      expect(ids('user'), contains('cached'));
      expect(
        ids('user').indexOf('cached'),
        greaterThan(ids('user').indexOf('repo')),
      );
    });

    test('finds acronyms', () {
      // wac: Weather Api Client (not Weather Cache).
      expect(ids('wac').first, 'client');
    });

    test('finds names that contain the query', () {
      expect(ids('ather'), containsAll(['weather', 'cache', 'client']));
    });

    test('finds fuzzy matches (the letters in order)', () {
      expect(ids('wthrcl'), ['client']);
    });

    test('finds members through their qualified name', () {
      expect(ids('repository.sa'), ['save']);
      // Letters in order in the qualified name only.
      expect(ids('urs'), contains('save'));
    });

    test('is not case sensitive', () {
      expect(ids('WEATHERCACHE'), ['cache']);
      expect(ids('Http'), ['http']);
    });

    test('gives the kind and the file of each result', () {
      final result = index.search('save').single;

      expect(result.id, 'save');
      expect(result.kind, CodeNodeKind.method);
      expect(result.filePath, 'lib/user_repository.dart');
      expect(result.qualifiedName, 'UserRepository.save');
      expect(index.search('http').single.filePath, isNull);
    });

    test('keeps only the best matches', () {
      expect(index.search('e', limit: 3), hasLength(3));
      expect(index.search('e').length, greaterThan(3));
    });

    test('breaks ties by the shorter name, then the name', () {
      // All three contain "ea" after their first letter, at the same place.
      final results = ids('ather');

      expect(results.first, 'weather');
    });

    test('is built once per map', () {
      final map = _searchMap();

      expect(SearchIndex.of(map), same(SearchIndex.of(map)));
    });

    test('searches a real map by class name', () {
      final results = SearchIndex(sampleMap()).search('WeatherCache');

      expect(results.first.name, 'WeatherCache');
      expect(results.first.kind, CodeNodeKind.classDecl);
    });

    test('searches the nested map', () {
      expect(
        SearchIndex(nestedMap()).search('n').map((r) => r.id),
        contains('A.B.n'),
      );
    });
  });

  group(fuzzyScore, () {
    test('is null when the letters do not appear in order', () {
      expect(fuzzyScore('ba', 'ab'), isNull);
      expect(fuzzyScore('abc', 'ab'), isNull);
    });

    test('is zero for an empty query', () {
      expect(fuzzyScore('', 'anything'), 0);
    });

    test('ignores case in both', () {
      expect(fuzzyScore('WC', 'weathercache'), isNotNull);
      expect(fuzzyScore('wc', 'WeatherCache'), isNotNull);
    });

    test('likes consecutive letters', () {
      expect(
        fuzzyScore('abc', 'abcxxx'),
        greaterThan(fuzzyScore('abc', 'axbxcx')!),
      );
    });

    test('likes letters that start a word', () {
      // Camel humps, underscores and dots all start words.
      final humps = fuzzyScore('wc', 'WeatherCache')!;
      final middle = fuzzyScore('wc', 'awbcdefghijk')!;
      expect(humps, greaterThan(middle));
      expect(
        fuzzyScore('sr', 'save_result'),
        greaterThan(fuzzyScore('sr', 'sxxrxxxxxx')!),
      );
      expect(
        fuzzyScore('ud', 'user.data'),
        greaterThan(fuzzyScore('ud', 'usxrxdata')!),
      );
    });

    test('prefers a shorter text', () {
      expect(
        fuzzyScore('ab', 'ab'),
        greaterThan(fuzzyScore('ab', 'abcdefgh')!),
      );
    });
  });

  test('results compare by value', () {
    SearchResult result() => SearchResult(
      id: 'a',
      name: 'a',
      qualifiedName: 'a',
      kind: CodeNodeKind.method,
      score: [1.0].first,
    );

    expect(result(), result());
    expect(result().props, hasLength(6));
  });
}
