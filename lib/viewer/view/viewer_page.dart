import 'dart:async';
import 'dart:math' as math;

import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:dart_code_3d/viewer/bloc/viewer_bloc.dart';
import 'package:dart_code_3d/viewer/models/code_map_source.dart';
import 'package:dart_code_3d/viewer/models/local_file.dart';
import 'package:dart_code_3d/viewer/models/node_details.dart';
import 'package:dart_code_3d/viewer/navigation/fly_controls.dart';
import 'package:dart_code_3d/viewer/navigation/world_controller.dart';
import 'package:dart_code_3d/viewer/view/code_world_view.dart';
import 'package:dart_code_3d/viewer/widgets/debug_overlay.dart';
import 'package:dart_code_3d/viewer/widgets/info_panel.dart';
import 'package:dart_code_3d/viewer/widgets/search_overlay.dart';
import 'package:dart_code_3d/viewer/widgets/viewer_hud.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings_repository/settings_repository.dart';

/// Opens a code map from [source] and shows it in 3D.
class ViewerPage extends StatelessWidget {
  const new({this.source = CodeMapSource.sample, super.key});

  /// Where the code map is read from.
  final CodeMapSource source;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ViewerBloc(
        repository: context.read<CodeMapRepository>(),
        loadAsset: rootBundle.load,
        readFile: readLocalFile,
      )..add(ViewerOpened(source)),
      child: const ViewerView(),
    );
  }
}

/// Shows the viewer's state. [sceneBuilder] draws the 3D area (injectable:
/// widget tests have no GPU).
class ViewerView extends StatefulWidget {
  const new({super.key, this.initialize, this.sceneBuilder});

  /// Loads the renderer's resources (flutter_scene's by default).
  final Future<void> Function()? initialize;

  /// Draws the 3D area ([buildCodeWorldScene] by default).
  final CodeWorldSceneBuilder? sceneBuilder;

  @override
  State<ViewerView> createState() => _ViewerViewState();
}

class _ViewerViewState extends State<ViewerView> {
  /// Screens at least this wide get the info panel as a side sheet.
  static const _wideBreakpoint = 720.0;
  static const _sidePanelWidth = 360.0;

  bool _debugOverlay = false;
  bool _searching = false;
  final _worldController = WorldController();

  // The details of the selected node, worked out once per selection.
  NodeDetails? _details;
  CodeMap? _detailsMap;

  @override
  void dispose() {
    _worldController.dispose();
    super.dispose();
  }

  NodeDetails? _detailsOf(ViewerReady ready) {
    final id = ready.selectedId;
    if (id == null) return null;
    final cached = _details;
    if (cached != null &&
        cached.id == id &&
        identical(_detailsMap, ready.map)) {
      return cached;
    }
    _detailsMap = ready.map;
    return _details = NodeDetails.of(ready.map, id);
  }

  Widget _ready(
    BuildContext context,
    ViewerBloc bloc,
    ViewerReady ready,
    TouchControlsMode touchControls,
    BoxConstraints constraints,
  ) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final wide = constraints.maxWidth >= _wideBreakpoint;
    final details = _detailsOf(ready);
    void select(String? id) => bloc.add(ViewerNodeSelected(id));
    void flyTo(String id) {
      select(id);
      _worldController.flyToNode(id, animate: animate);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CodeWorldView(
          map: ready.map,
          initialize: widget.initialize ?? CodeWorldView.defaultInitialize,
          sceneBuilder: widget.sceneBuilder ?? buildCodeWorldScene,
          visible: ready.visible,
          viewMode: ready.viewMode,
          controller: _worldController,
          selectedId: ready.selectedId,
          labelsOn: ready.labelsOn,
          touchControls: touchControls,
          // A bottom sheet would cover the touch controls.
          hideTouchControls: details != null && !wide,
          onContainerChanged: (id) => bloc.add(ViewerContainerChanged(id)),
          onSelect: select,
          // The toggle only means something inside a sphere.
          onToggleViewMode: ready.currentContainerId == null
              ? null
              : () => bloc.add(const ViewerViewModeToggled()),
          onToggleLabels: () => bloc.add(const ViewerLabelsToggled()),
          onSearch: () => setState(() => _searching = true),
          onHelp: () => ControlsHelpDialog.show(context),
        ),
        ViewerHud(
          state: ready,
          controller: _worldController,
          endInset: details != null && wide ? _sidePanelWidth : 0,
          onCrumbTap: (id) =>
              _worldController.flyToContainer(id, animate: animate),
          onToggleViewMode: () => bloc.add(const ViewerViewModeToggled()),
          onToggleLinkKind: (kind) => bloc.add(ViewerLinkKindToggled(kind)),
          onSearch: () => setState(() => _searching = true),
          onToggleLabels: () => bloc.add(const ViewerLabelsToggled()),
          onSelectNode: flyTo,
        ),
        if (details != null)
          _panel(context, bloc, ready, details, wide, constraints, animate),
        if (_searching)
          SearchOverlay(
            map: ready.map,
            onClose: () => setState(() => _searching = false),
            onSelect: (id) {
              setState(() => _searching = false);
              flyTo(id);
            },
          ),
        if (_debugOverlay)
          DebugOverlay(
            instanceCount: ready.visible.visibleSpheres.length,
            linkCount: ready.visible.links.length,
          ),
      ],
    );
  }

  Widget _panel(
    BuildContext context,
    ViewerBloc bloc,
    ViewerReady ready,
    NodeDetails details,
    bool wide,
    BoxConstraints constraints,
    bool animate,
  ) {
    final panel = InfoPanel(
      details: details,
      focusOn: ready.focusOnSelected,
      bottomSheet: !wide,
      onFlyTo: () => _worldController.flyToNode(details.id, animate: animate),
      onEnter: details.isEnterable
          ? () => _worldController.flyToContainer(details.id, animate: animate)
          : null,
      onToggleFocus: () => bloc.add(const ViewerFocusToggled()),
      onCopyPath: () {
        unawaited(Clipboard.setData(ClipboardData(text: details.copyablePath)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.infoCopied(details.copyablePath)),
          ),
        );
      },
      onClose: () => bloc.add(const ViewerNodeSelected(null)),
    );
    return wide
        ? PositionedDirectional(
            top: 0,
            bottom: 0,
            end: 0,
            width: _sidePanelWidth,
            child: panel,
          )
        : PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            height: math.min(constraints.maxHeight * 0.5, 420),
            child: panel,
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.watch<ViewerBloc>();
    final state = bloc.state;
    final developer = context.read<AppFlavor>() == AppFlavor.development;
    final touchControls = context.select<SettingsBloc, TouchControlsMode>(
      (bloc) => bloc.state.touchControls,
    );
    final title = switch (state) {
      ViewerReady(:final map) => map.graph.project.source.label,
      _ => l10n.appTitle,
    };
    final body = switch (state) {
      ViewerLoading() => _Message(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: context.spacing.md),
            Text(l10n.viewerOpening),
          ],
        ),
      ),
      ViewerFailure(:final details, :final kind) => _Failure(
        details: details,
        kind: kind,
      ),
      final ViewerReady ready => LayoutBuilder(
        builder: (context, constraints) =>
            _ready(context, bloc, ready, touchControls, constraints),
      ),
    };
    return CallbackShortcuts(
      bindings: {
        if (developer)
          const SingleActivator(LogicalKeyboardKey.f3): () =>
              setState(() => _debugOverlay = !_debugOverlay),
      },
      // The 3D area (FlyControls) holds the focus; F3 bubbles up to here.
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (state is ViewerReady)
              IconButton(
                tooltip: l10n.viewerControlsTooltip,
                icon: const Icon(Icons.keyboard_outlined),
                onPressed: () => ControlsHelpDialog.show(context),
              ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: EdgeInsets.all(context.spacing.lg), child: child),
  );
}

class _Failure extends StatelessWidget {
  const new({required this.details, required this.kind});

  final String details;
  final ViewerFailureKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return _Message(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: theme.colorScheme.error,
          ),
          SizedBox(height: spacing.md),
          Text(
            switch (kind) {
              ViewerFailureKind.unreadable => l10n.viewerNotACodeMap,
              ViewerFailureKind.missing => l10n.viewerMapMissing,
            },
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.sm),
          Text(
            switch (kind) {
              ViewerFailureKind.unreadable => details,
              ViewerFailureKind.missing => l10n.viewerMapMissingHint,
            },
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.lg),
          FilledButton.icon(
            icon: const Icon(Icons.home_outlined),
            label: Text(l10n.viewerBackHome),
            onPressed: () => const HomeRoute().go(context),
          ),
        ],
      ),
    );
  }
}
