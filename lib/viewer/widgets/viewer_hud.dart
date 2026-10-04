import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The heads-up display over the 3D area: a summary of the open map.
class ViewerHud extends StatelessWidget {
  const new({required this.map, super.key});

  /// The open map.
  final CodeMap map;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.85,
              ),
              borderRadius: BorderRadius.circular(spacing.sm),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              child: Text(
                context.l10n.viewerStats(
                  map.graph.nodes.length,
                  map.graph.links.length,
                ),
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
