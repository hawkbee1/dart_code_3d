import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:dart_code_3d/viewer/bloc/viewer_bloc.dart';
import 'package:dart_code_3d/viewer/models/code_map_source.dart';
import 'package:dart_code_3d/viewer/models/local_file.dart';
import 'package:dart_code_3d/viewer/navigation/fly_controls.dart';
import 'package:dart_code_3d/viewer/view/code_world_view.dart';
import 'package:dart_code_3d/viewer/widgets/debug_overlay.dart';
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
  bool _debugOverlay = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ViewerBloc>().state;
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
      ViewerFailure(:final details) => _Failure(details: details),
      ViewerReady(:final map) => Stack(
        fit: StackFit.expand,
        children: [
          CodeWorldView(
            map: map,
            initialize: widget.initialize ?? CodeWorldView.defaultInitialize,
            sceneBuilder: widget.sceneBuilder ?? buildCodeWorldScene,
            touchControls: touchControls,
            onContainerChanged: (id) =>
                context.read<ViewerBloc>().add(ViewerContainerChanged(id)),
            onHelp: () => ControlsHelpDialog.show(context),
          ),
          ViewerHud(map: map),
          if (_debugOverlay)
            DebugOverlay(instanceCount: map.graph.topLevel.length),
        ],
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
  const new({required this.details});

  final String details;

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
            l10n.viewerNotACodeMap,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.sm),
          Text(
            details,
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
