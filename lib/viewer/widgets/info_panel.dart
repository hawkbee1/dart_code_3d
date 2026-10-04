import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/models/node_details.dart';
import 'package:dart_code_3d/viewer/widgets/link_kind_texts.dart';
import 'package:dart_code_3d/viewer/widgets/node_kind_texts.dart';
import 'package:material_ui/material_ui.dart';

/// The details of the selected node: what it is and where it is, what it
/// holds, how it is linked (and how far to trust the links), and the actions
/// on it. A side sheet on wide screens, a bottom sheet on phones
/// ([bottomSheet]); the content scrolls.
class InfoPanel extends StatelessWidget {
  const new({
    required this.details,
    required this.focusOn,
    required this.onFlyTo,
    required this.onToggleFocus,
    required this.onCopyPath,
    required this.onClose,
    super.key,
    this.onEnter,
    this.bottomSheet = false,
  });

  /// What to show.
  final NodeDetails details;

  /// Whether only the links of this node are drawn.
  final bool focusOn;

  /// Flies the camera to the node.
  final VoidCallback onFlyTo;

  /// Flies the camera into the node; null when it cannot be entered.
  final VoidCallback? onEnter;

  /// Shows only the links of the node, or all of them again.
  final VoidCallback onToggleFocus;

  /// Copies the node's location (or its qualified name).
  final VoidCallback onCopyPath;

  /// Deselects the node.
  final VoidCallback onClose;

  /// Whether it is a bottom sheet (rounded top) rather than a side sheet.
  final bool bottomSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final details = this.details;
    final holds = details.members > 0 || details.nested > 0;
    final isGhost = details.kind == CodeNodeKind.ghostParent;
    final isPackage = details.kind == CodeNodeKind.externalPackage;

    Widget field(String label, String value) => Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    final outline = BorderSide(color: theme.colorScheme.outlineVariant);

    Widget line(String text) => Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.infoPanelLabel(details.name),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: bottomSheet
              ? BorderRadius.vertical(top: Radius.circular(spacing.md))
              : BorderRadius.zero,
        ),
        clipBehavior: Clip.antiAlias,
        // An outline on the side facing the world, instead of a shadow.
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: bottomSheet
                ? Border(top: outline)
                : BorderDirectional(start: outline),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.md,
                  top: spacing.sm,
                  end: spacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: spacing.sm),
                      child: Icon(
                        nodeKindIcon(details.kind),
                        color: context.worldColors.nodes[details.kind],
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: spacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details.name,
                              style: theme.textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.nodeKindLabel(details.kind),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.infoClose,
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(spacing.md),
                  children: [
                    if (details.qualifiedName != details.name)
                      field(l10n.infoQualifiedName, details.qualifiedName),
                    if (details.location case final location?)
                      field(l10n.infoLocation, location),
                    if (!isGhost && !isPackage)
                      line(l10n.infoLinesOfCode(details.loc)),
                    if (!isGhost && !isPackage && holds)
                      line(
                        '${l10n.infoMembers(details.members)} · '
                        '${l10n.infoNested(details.nested)}',
                      ),
                    if (isGhost || isPackage)
                      line(
                        details.packageName == null
                            ? l10n.infoPackageUnknown
                            : l10n.infoPackage(details.packageName!),
                      ),
                    if (isGhost && holds) line(l10n.infoNested(details.nested)),
                    if (isPackage) line(l10n.infoPackageModelUnavailable),
                    SizedBox(height: spacing.xs),
                    Text(l10n.infoLinks, style: theme.textTheme.titleSmall),
                    SizedBox(height: spacing.xs),
                    if (details.links.isEmpty)
                      Text(l10n.infoNoLinks, style: theme.textTheme.bodyMedium),
                    for (final stats in details.links) _LinkStats(stats: stats),
                    if (details.links.any(
                      (l) =>
                          l.outgoing.total + l.incoming.total >
                          l.outgoing.exact + l.incoming.exact,
                    ))
                      Text(
                        l10n.infoResolutionHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: Wrap(
                  spacing: spacing.sm,
                  runSpacing: spacing.xs,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.flight_takeoff),
                      label: Text(l10n.infoFlyTo),
                      onPressed: onFlyTo,
                    ),
                    if (onEnter != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.login),
                        label: Text(l10n.infoEnter),
                        onPressed: onEnter,
                      ),
                    if (details.links.isNotEmpty || focusOn)
                      OutlinedButton.icon(
                        icon: Icon(focusOn ? Icons.link : Icons.filter_alt),
                        label: Text(
                          focusOn ? l10n.infoShowAllLinks : l10n.infoFocusLinks,
                        ),
                        onPressed: onToggleFocus,
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.infoCopyPath),
                      onPressed: onCopyPath,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkStats extends StatelessWidget {
  const new({required this.stats});

  final LinkKindStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final colors = theme.colorScheme;
    int count(LinkResolution r) => stats.outgoing.of(r) + stats.incoming.of(r);
    final resolutionColors = {
      LinkResolution.exact: colors.primary,
      LinkResolution.byName: colors.tertiary,
      LinkResolution.ambiguous: colors.error,
      LinkResolution.external: colors.outline,
    };
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.infoLinkCounts(
              l10n.linkKindLabel(stats.kind),
              stats.outgoing.total,
              stats.incoming.total,
            ),
            style: theme.textTheme.bodyMedium,
          ),
          Wrap(
            spacing: spacing.sm,
            children: [
              for (final resolution in LinkResolution.values)
                if (count(resolution) > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: resolutionColors[resolution],
                      ),
                      SizedBox(width: spacing.xs),
                      Text(
                        '${l10n.resolutionLabel(resolution)} '
                        '${count(resolution)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
