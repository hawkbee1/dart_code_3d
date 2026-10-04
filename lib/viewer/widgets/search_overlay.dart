import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/search/search_index.dart';
import 'package:dart_code_3d/viewer/widgets/node_kind_texts.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A search box with its results over the 3D area (`/` or Ctrl/Cmd+F).
///
/// Typing searches the names and qualified names of the whole map; `↑`/`↓`
/// move through the results, `Enter` or a tap picks one ([onSelect]) and
/// `Esc` (or the close button) closes the search ([onClose]).
class SearchOverlay extends StatefulWidget {
  const new({
    required this.map,
    required this.onSelect,
    required this.onClose,
    super.key,
  });

  /// The code map searched.
  final CodeMap map;

  /// Called with the id of the node picked.
  final ValueChanged<String> onSelect;

  /// Called to close the search.
  final VoidCallback onClose;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _controller = TextEditingController();
  // The key handler goes on the field's own focus node: it runs before the
  // text field's shortcuts, which would swallow the arrow keys.
  late final _focusNode = FocusNode(debugLabel: 'search', onKeyEvent: _onKey);
  var _results = const <SearchResult>[];
  var _highlighted = 0;

  @override
  void initState() {
    super.initState();
    // `autofocus` only takes the focus when nothing has it, and the 3D area
    // does: ask for it.
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String query) => setState(() {
    _results = SearchIndex.of(widget.map).search(query);
    _highlighted = 0;
  });

  void _pick(SearchResult result) => widget.onSelect(result.id);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else if (key == LogicalKeyboardKey.arrowDown && _results.isNotEmpty) {
      setState(() => _highlighted = (_highlighted + 1) % _results.length);
    } else if (key == LogicalKeyboardKey.arrowUp && _results.isNotEmpty) {
      setState(
        () => _highlighted =
            (_highlighted - 1 + _results.length) % _results.length,
      );
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final query = _controller.text.trim();
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 440),
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(spacing.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: l10n.searchClose,
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(spacing.md),
                  ),
                  onChanged: _search,
                  onSubmitted: (_) {
                    if (_results.isNotEmpty) _pick(_results[_highlighted]);
                  },
                ),
                const Divider(height: 1),
                if (query.isEmpty)
                  _Message(l10n.searchEmpty)
                else if (_results.isEmpty)
                  _Message(l10n.searchNoMatch(query))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final result = _results[i];
                        final kind = l10n.nodeKindLabel(result.kind);
                        return Semantics(
                          label: l10n.searchResultLabel(result.name, kind),
                          excludeSemantics: true,
                          button: true,
                          child: ListTile(
                            dense: true,
                            selected: i == _highlighted,
                            leading: Icon(
                              nodeKindIcon(result.kind),
                              color: context.worldColors.nodes[result.kind],
                            ),
                            title: Text(
                              result.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                kind,
                                if (result.filePath != null) result.filePath!,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pick(result),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.spacing.md),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
