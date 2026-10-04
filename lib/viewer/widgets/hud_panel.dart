import 'package:dart_code_3d/app/app.dart';
import 'package:material_ui/material_ui.dart';

/// A translucent rounded panel that stays readable over the 3D area.
class HudPanel extends StatelessWidget {
  const new({required this.child, super.key, this.padding});

  /// The content.
  final Widget child;

  /// Space around [child] (a small default).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(spacing.sm),
      ),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
        child: child,
      ),
    );
  }
}
