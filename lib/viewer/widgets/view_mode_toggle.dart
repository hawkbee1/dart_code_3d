import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/widgets/hud_panel.dart';
import 'package:dart_code_3d/viewer/world/visibility.dart';
import 'package:material_ui/material_ui.dart';

/// Switches between the inside view and the window view (key `V`).
class ViewModeToggle extends StatelessWidget {
  const new({required this.mode, required this.onToggle, super.key});

  /// The current mode.
  final ViewMode mode;

  /// Called to switch to the other mode.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final window = mode == ViewMode.window;
    return Tooltip(
      message: l10n.viewerToggleViewTooltip,
      child: HudPanel(
        padding: EdgeInsets.zero,
        child: TextButton.icon(
          onPressed: onToggle,
          icon: Icon(window ? Icons.window_outlined : Icons.blur_circular),
          label: Text(window ? l10n.viewerViewWindow : l10n.viewerViewInterior),
        ),
      ),
    );
  }
}
