import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/widgets/hud_panel.dart';
import 'package:material_ui/material_ui.dart';

/// One level of the breadcrumb: `id` is the container it flies to (the
/// world when null) and `name` its label.
typedef Crumb = ({String? id, String name});

/// Where the camera is: `World › UserRepository › CachedUserRepository`.
///
/// Tapping a crumb flies out to that level; the last one, where the camera
/// is, is plain text. Each name is cut with an ellipsis after
/// [maxCrumbWidth], and a long path wraps onto more lines.
class Breadcrumb extends StatelessWidget {
  const new({required this.path, required this.onCrumbTap, super.key});

  /// The levels, the world first and the current container last.
  final List<Crumb> path;

  /// Called with the container to fly to (the world when null).
  final ValueChanged<String?> onCrumbTap;

  /// The widest a crumb gets before its name is cut.
  static const double maxCrumbWidth = 160;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return Semantics(
      container: true,
      // Each crumb or chip stays a node of its own for screen readers.
      explicitChildNodes: true,
      label: l10n.viewerBreadcrumbRegion,
      child: HudPanel(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, crumb) in path.indexed) ...[
              if (i > 0)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxCrumbWidth),
                child: i == path.length - 1
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                        child: Text(
                          crumb.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      )
                    : Semantics(
                        label: l10n.viewerBreadcrumbLabel(crumb.name),
                        excludeSemantics: true,
                        button: true,
                        child: TextButton(
                          onPressed: () => onCrumbTap(crumb.id),
                          child: Text(
                            crumb.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
