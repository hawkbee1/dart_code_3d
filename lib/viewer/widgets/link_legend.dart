import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/widgets/link_kind_texts.dart';
import 'package:material_ui/material_ui.dart';

/// The link kinds of the map, each a chip in its link color: tapping one
/// shows or hides those links.
class LinkLegend extends StatelessWidget {
  const new({
    required this.kinds,
    required this.visibleKinds,
    required this.onToggle,
    super.key,
  });

  /// The kinds the map has links of.
  final List<LinkKind> kinds;

  /// The kinds currently drawn.
  final Set<LinkKind> visibleKinds;

  /// Called with the kind to show or hide.
  final ValueChanged<LinkKind> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final colors = context.worldColors;
    return Semantics(
      container: true,
      // Each crumb or chip stays a node of its own for screen readers.
      explicitChildNodes: true,
      label: l10n.viewerLegendRegion,
      child: Wrap(
        spacing: spacing.sm,
        runSpacing: spacing.xs,
        children: [
          for (final kind in kinds)
            FilterChip(
              avatar: Icon(Icons.circle, size: 14, color: colors.links[kind]),
              label: Text(l10n.linkKindLabel(kind)),
              selected: visibleKinds.contains(kind),
              onSelected: (_) => onToggle(kind),
            ),
        ],
      ),
    );
  }
}
