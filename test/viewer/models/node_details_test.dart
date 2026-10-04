import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/code_maps.dart';

void main() {
  group(NodeDetails, () {
    late CodeMap map;

    setUp(() => map = nestedMap());

    NodeDetails details(String id) => NodeDetails.of(map, id);

    LinkKindStats stats(NodeDetails d, LinkKind kind) =>
        d.links.singleWhere((l) => l.kind == kind);

    test('compares by value', () {
      final a = details('A');

      expect(a, details('A'));
      expect(a, isNot(details('A.m')));
      expect(a.props, hasLength(12));
    });

    test('reads the identity of a node', () {
      final a = details('A');

      expect(a.id, 'A');
      expect(a.name, 'A');
      expect(a.qualifiedName, 'A');
      expect(a.kind, CodeNodeKind.classDecl);
      expect(a.loc, 0);
    });

    test('counts members and nested types of a container', () {
      final a = details('A');

      expect(a.members, 1);
      expect(a.nested, 1);
      expect(a.isEnterable, isTrue);
      expect(details('A.m').members, 0);
      expect(details('A.m').isEnterable, isFalse);
    });

    test('counts the links that cross the boundary of the node', () {
      final a = details('A');

      expect(a.links.map((l) => l.kind), [
        LinkKind.call,
        LinkKind.import,
        LinkKind.implementsLink,
      ]);
      // A.m → C.k (exact) and A.B.n → C.k (ambiguous) leave; main → A.m and
      // G.D.p → A.m (exact) arrive. A.m → A.B.n stays inside.
      final calls = stats(a, LinkKind.call);
      expect(calls.outgoing, const ResolutionCounts(exact: 1, ambiguous: 1));
      expect(calls.incoming, const ResolutionCounts(exact: 2));
      expect(stats(a, LinkKind.implementsLink).outgoing.total, 1);
      expect(stats(a, LinkKind.implementsLink).incoming.total, 0);
      expect(stats(a, LinkKind.import).incoming.total, 1);
    });

    test('counts the links of a single member', () {
      final method = details('A.m');

      final calls = stats(method, LinkKind.call);
      // To C.k and to A.B.n (it is not inside A.m): both leave.
      expect(calls.outgoing.exact, 2);
      expect(calls.incoming.exact, 2);
    });

    test('tells how far to trust the links', () {
      final package = details('pkg');

      expect(
        stats(package, LinkKind.call).incoming,
        const ResolutionCounts(external: 1),
      );
      expect(package.links, hasLength(1));
    });

    test('an external package is not enterable', () {
      expect(details('pkg').isEnterable, isFalse);
      expect(details('pkg').kind, CodeNodeKind.externalPackage);
    });

    test('has no links for an isolated node', () {
      expect(details('G.D.p').links, hasLength(1));
      expect(NodeDetails.of(mapWithoutLinks(), 'A').links, isEmpty);
    });

    group('in a real map', () {
      late CodeMap sample;

      setUp(() => sample = sampleMap());

      String idOf(String name) =>
          sample.graph.nodes.values.firstWhere((n) => n.name == name).id;

      test('gives the file and the lines of a class', () {
        final cache = NodeDetails.of(sample, idOf('WeatherCache'));

        expect(cache.filePath, 'lib/weather/data/weather_cache.dart');
        expect(cache.startLine, 9);
        expect(
          cache.location,
          startsWith('lib/weather/data/weather_cache.dart:9–'),
        );
        expect(cache.copyablePath, cache.location);
        expect(cache.nested, 1);
        expect(cache.members, 3);
      });

      test('gives the package of a ghost parent', () {
        final ghost = NodeDetails.of(sample, idOf('Cubit'));

        expect(ghost.kind, CodeNodeKind.ghostParent);
        expect(ghost.packageName, 'bloc');
        expect(ghost.location, isNull);
        expect(ghost.isEnterable, isTrue);
      });
    });

    group('location', () {
      NodeDetails at({String? path, int? start, int? end}) => NodeDetails(
        id: 'a',
        name: 'a',
        qualifiedName: 'A.a',
        kind: CodeNodeKind.method,
        loc: 1,
        members: 0,
        nested: 0,
        links: const [],
        filePath: path,
        startLine: start,
        endLine: end,
      );

      test('shows the lines of a range', () {
        expect(
          at(path: 'lib/a.dart', start: 3, end: 9).location,
          'lib/a.dart:3–9',
        );
      });

      test('shows a single line once', () {
        expect(
          at(path: 'lib/a.dart', start: 3, end: 3).location,
          'lib/a.dart:3',
        );
        expect(at(path: 'lib/a.dart', start: 3).location, 'lib/a.dart:3');
      });

      test('shows the file alone without lines', () {
        expect(at(path: 'lib/a.dart').location, 'lib/a.dart');
      });

      test('copies the qualified name when there is no location', () {
        final noFile = at();

        expect(noFile.location, isNull);
        expect(noFile.copyablePath, 'A.a');
      });
    });
  });

  group(ResolutionCounts, () {
    test('adds up and counts by resolution', () {
      var counts = const ResolutionCounts();
      for (final resolution in [
        LinkResolution.exact,
        LinkResolution.exact,
        LinkResolution.byName,
        LinkResolution.ambiguous,
        LinkResolution.external,
        LinkResolution.external,
        LinkResolution.external,
      ]) {
        counts = counts.plusOne(resolution);
      }

      expect(counts.total, 7);
      expect(counts.of(LinkResolution.exact), 2);
      expect(counts.of(LinkResolution.byName), 1);
      expect(counts.of(LinkResolution.ambiguous), 1);
      expect(counts.of(LinkResolution.external), 3);
    });

    test('compare by value', () {
      ResolutionCounts counts() => ResolutionCounts(exact: [1].length);

      expect(counts(), counts());
      expect(counts().props, hasLength(4));
      LinkKindStats stats() => LinkKindStats(
        kind: LinkKind.call,
        outgoing: counts(),
        incoming: const ResolutionCounts(),
      );
      expect(stats(), stats());
      expect(stats().props, hasLength(3));
    });
  });
}
