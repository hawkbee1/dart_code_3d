import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/bloc/viewer_bloc.dart';
import 'package:dart_code_3d/viewer/navigation/world_controller.dart';
import 'package:dart_code_3d/viewer/widgets/breadcrumb.dart';
import 'package:dart_code_3d/viewer/widgets/hud_panel.dart';
import 'package:dart_code_3d/viewer/widgets/hud_toolbar.dart';
import 'package:dart_code_3d/viewer/widgets/link_legend.dart';
import 'package:dart_code_3d/viewer/widgets/minimap.dart';
import 'package:dart_code_3d/viewer/widgets/view_mode_toggle.dart';
import 'package:dart_code_3d/viewer/world/visibility.dart';
import 'package:material_ui/material_ui.dart';

/// The heads-up display over the 3D area: where the camera is (breadcrumb),
/// the inside/window toggle (inside a sphere), the link legend, the toolbar
/// (search, labels), the minimap, and a summary of the open map.
class ViewerHud extends StatelessWidget {
  const new({
    required this.state,
    required this.controller,
    required this.onCrumbTap,
    required this.onToggleViewMode,
    required this.onToggleLinkKind,
    required this.onSearch,
    required this.onToggleLabels,
    required this.onSelectNode,
    super.key,
    this.endInset = 0,
  });

  /// The open map and what is shown of it.
  final ViewerReady state;

  /// Where the camera is (the minimap draws it).
  final WorldController controller;

  /// Called with the container to fly to (the world when null).
  final ValueChanged<String?> onCrumbTap;

  /// Called to switch between inside and window view.
  final VoidCallback onToggleViewMode;

  /// Called with the link kind to show or hide.
  final ValueChanged<LinkKind> onToggleLinkKind;

  /// Called to open the search.
  final VoidCallback onSearch;

  /// Called to show or hide the labels.
  final VoidCallback onToggleLabels;

  /// Called with a node picked on the minimap.
  final ValueChanged<String> onSelectNode;

  /// Space kept free at the end, where a side sheet covers the view.
  final double endInset;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final graph = state.map.graph;
    final open = state.visible.openContainers;
    final linkKinds = VisibilityIndex.of(state.map).linkKinds;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: endInset),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Breadcrumb(
                              path: [
                                (id: null, name: context.l10n.viewerWorldCrumb),
                                for (final id in open)
                                  (id: id, name: graph.nodes[id]!.name),
                              ],
                              onCrumbTap: onCrumbTap,
                            ),
                            if (open.isNotEmpty) ...[
                              SizedBox(height: spacing.sm),
                              ViewModeToggle(
                                mode: state.viewMode,
                                onToggle: onToggleViewMode,
                              ),
                            ],
                            if (linkKinds.isNotEmpty) ...[
                              SizedBox(height: spacing.sm),
                              LinkLegend(
                                kinds: linkKinds,
                                visibleKinds: state.visibleLinkKinds,
                                onToggle: onToggleLinkKind,
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HudToolbar(
                            labelsOn: state.labelsOn,
                            onSearch: onSearch,
                            onToggleLabels: onToggleLabels,
                          ),
                          SizedBox(height: spacing.sm),
                          Minimap(
                            map: state.map,
                            containerId: state.currentContainerId,
                            controller: controller,
                            selectedId: state.selectedId,
                            onSelect: onSelectNode,
                            // A phone has no room for it until asked.
                            initiallyExpanded: constraints.maxWidth >= 600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: HudPanel(
                  child: Text(
                    context.l10n.viewerStats(
                      graph.nodes.length,
                      graph.links.length,
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
