import 'package:code_graph/code_graph.dart';
import 'package:equatable/equatable.dart';

/// A node found by a search.
class SearchResult extends Equatable {
  /// Creates a result.
  const new({
    required this.id,
    required this.name,
    required this.qualifiedName,
    required this.kind,
    required this.score,
    this.filePath,
  });

  /// The node's id.
  final String id;

  /// The node's name.
  final String name;

  /// The node's qualified name (`Class.member`).
  final String qualifiedName;

  /// What the node is.
  final CodeNodeKind kind;

  /// The file that declares it, when it has one.
  final String? filePath;

  /// How well it matches: higher is better.
  final double score;

  @override
  List<Object?> get props => [id, name, qualifiedName, kind, filePath, score];
}

/// How well [query] matches [text] as a (case-insensitive) subsequence: null
/// when its letters do not appear in [text] in that order, otherwise a score
/// that grows with consecutive letters and letters starting a word (after a
/// separator, or a capital after a lowercase letter), and shrinks with the
/// letters skipped.
double? fuzzyScore(String query, String text) {
  final q = query.toLowerCase();
  if (q.isEmpty) return 0;
  var next = 0;
  var score = 0.0;
  var previousMatched = false;
  for (var i = 0; i < text.length && next < q.length; i++) {
    final char = text[i];
    if (char.toLowerCase() != q[next]) {
      previousMatched = false;
      continue;
    }
    score += 10;
    if (previousMatched) score += 15;
    if (_startsWord(text, i)) score += 10;
    previousMatched = true;
    next++;
  }
  if (next < q.length) return null;
  return score - (text.length - q.length) * 0.1;
}

bool _startsWord(String text, int i) {
  if (i == 0) return true;
  final previous = text[i - 1];
  if (previous == '.' ||
      previous == '_' ||
      previous == '-' ||
      previous == ' ') {
    return true;
  }
  final isUpper = text[i] != text[i].toLowerCase();
  final previousIsLower =
      previous == previous.toLowerCase() && previous != previous.toUpperCase();
  return isUpper && previousIsLower;
}

/// The words of a name: split at separators and before capitals.
List<String> _words(String name) {
  final words = <String>[];
  var start = 0;
  for (var i = 1; i <= name.length; i++) {
    if (i == name.length || _startsWord(name, i)) {
      final word = name.substring(start, i).replaceAll(RegExp('^[._ -]+'), '');
      if (word.isNotEmpty) words.add(word.toLowerCase());
      start = i;
    }
  }
  return words;
}

class _Entry {
  new(CodeNode node)
    : id = node.id,
      name = node.name,
      qualifiedName = node.qualifiedName,
      kind = node.kind,
      filePath = node.location?.filePath,
      nameLower = node.name.toLowerCase(),
      qualifiedLower = node.qualifiedName.toLowerCase(),
      words = _words(node.name) {
    initials = words.map((word) => word[0]).join();
  }

  final String id;
  final String name;
  final String qualifiedName;
  final CodeNodeKind kind;
  final String? filePath;
  final String nameLower;
  final String qualifiedLower;
  final List<String> words;

  /// The first letters of the words: `wac` for `WeatherApiClient`.
  late final String initials;
}

/// Searches the nodes of a code map by name and qualified name.
///
/// Matches are ranked: the exact name, then names that start with the query,
/// names with a word that starts with it, acronyms (`wac`), names that
/// contain it, then fuzzy matches (the letters in order), and last the
/// qualified name.
class SearchIndex {
  /// Indexes [map].
  new(CodeMap map)
    : _entries = [for (final node in map.graph.nodes.values) _Entry(node)];

  /// The index of [map], built once and shared.
  factory of(CodeMap map) => _indexes[map] ??= SearchIndex(map);

  static final _indexes = Expando<SearchIndex>('search index');

  final List<_Entry> _entries;

  /// The best [limit] matches of [query] (none for an empty one).
  List<SearchResult> search(String query, {int limit = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <SearchResult>[];
    for (final entry in _entries) {
      final score = _score(q, entry);
      if (score == null) continue;
      results.add(
        SearchResult(
          id: entry.id,
          name: entry.name,
          qualifiedName: entry.qualifiedName,
          kind: entry.kind,
          filePath: entry.filePath,
          score: score,
        ),
      );
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byLength = a.name.length.compareTo(b.name.length);
      if (byLength != 0) return byLength;
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
    return results.take(limit).toList();
  }

  double? _score(String q, _Entry entry) {
    final name = entry.nameLower;
    if (name == q) return 1000;
    if (name.startsWith(q)) {
      return 800.0 - (name.length - q.length).clamp(0, 100);
    }
    if (entry.words.any((word) => word.startsWith(q))) {
      return 600.0 - (name.length - q.length).clamp(0, 100);
    }
    // Acronym: `wac` finds WeatherApiClient.
    if (q.length >= 2 && entry.initials.startsWith(q)) {
      return 500.0 - (entry.initials.length - q.length).clamp(0, 50);
    }
    final index = name.indexOf(q);
    if (index >= 0) return 400.0 - index.clamp(0, 100);
    final fuzzy = fuzzyScore(q, entry.name);
    if (fuzzy != null) return 100 + fuzzy.clamp(0, 200);
    final qualified = entry.qualifiedLower.indexOf(q);
    if (qualified >= 0) return 80.0 - qualified.clamp(0, 50);
    final fuzzyQualified = fuzzyScore(q, entry.qualifiedName);
    if (fuzzyQualified != null) return 20 + fuzzyQualified.clamp(0, 50);
    return null;
  }
}
