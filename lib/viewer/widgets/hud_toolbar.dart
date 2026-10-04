import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/widgets/hud_panel.dart';
import 'package:material_ui/material_ui.dart';

/// The HUD's buttons: search, and showing or hiding the labels.
class HudToolbar extends StatelessWidget {
  const new({
    required this.labelsOn,
    required this.onSearch,
    required this.onToggleLabels,
    super.key,
  });

  /// Whether labels are shown.
  final bool labelsOn;

  /// Opens the search.
  final VoidCallback onSearch;

  /// Shows or hides the labels.
  final VoidCallback onToggleLabels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HudPanel(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.viewerSearchTooltip,
            icon: const Icon(Icons.search),
            onPressed: onSearch,
          ),
          IconButton(
            tooltip: l10n.viewerLabelsTooltip,
            isSelected: labelsOn,
            icon: const Icon(Icons.label_outline),
            selectedIcon: const Icon(Icons.label),
            onPressed: onToggleLabels,
          ),
        ],
      ),
    );
  }
}
