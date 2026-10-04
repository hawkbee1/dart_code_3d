import 'dart:async';

import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/bloc/home_cubit.dart';
import 'package:dart_code_3d/home/widgets/recent_map_tile.dart';
import 'package:dart_code_3d/home/widgets/web_storage_notice.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The first screen: the stored maps and the ways to make or open one.
class HomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) {
      final cubit = HomeCubit(
        repository: context.read<CodeMapRepository>(),
        dialogs: context.read<FileDialogs>(),
        exporter: context.read<FileExporter>(),
        exportMode: context.read<PlatformCapabilities>().exportMode,
      );
      unawaited(cubit.started());
      return cubit;
    },
    child: const HomeView(),
  );
}

/// The screen of [HomePage] over the [HomeCubit] above it.
class HomeView extends StatelessWidget {
  const new({super.key});

  void _tell(BuildContext context, HomeNotice notice) {
    final l10n = context.l10n;
    final cubit = context.read<HomeCubit>();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(switch (notice) {
        HomeMapDeleted(:final file) => SnackBar(
          content: Text(l10n.homeMapDeleted(file.name)),
          action: SnackBarAction(
            label: l10n.homeUndo,
            onPressed: () => cubit.deletionUndone(file),
          ),
        ),
        HomeFailed(:final failure) => SnackBar(
          content: Text(
            failure.kind == BuildFailureKind.invalidFile
                ? l10n.homeOpenFailed(l10n.failureBody(failure.kind))
                : l10n.failureTitle(failure.kind),
          ),
        ),
        HomeExportFailed() => SnackBar(content: Text(l10n.homeExportFailed)),
      });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final capabilities = context.read<PlatformCapabilities>();
    return BlocConsumer<HomeCubit, HomeState>(
      listenWhen: (previous, current) =>
          current.notice != null && current.notice != previous.notice,
      listener: (context, state) => _tell(context, state.notice!),
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();
        Future<void> openFile() async {
          final id = await cubit.fileOpened();
          if (id != null && context.mounted) ViewerRoute(id: id).go(context);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
            actions: [
              IconButton(
                tooltip: l10n.homeSettingsTooltip,
                icon: const Icon(Icons.settings),
                onPressed: () => const SettingsRoute().go(context),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.all(spacing.lg),
                children: [
                  if (!capabilities.persistentStorage) ...[
                    const WebStorageNotice(),
                    SizedBox(height: spacing.lg),
                  ],
                  if (state.status == HomeStatus.ready && state.maps.isEmpty)
                    _Hero(textTheme: textTheme),
                  _Actions(onOpenFile: openFile),
                  SizedBox(height: spacing.lg),
                  switch (state.status) {
                    HomeStatus.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    HomeStatus.failure => _LoadFailed(onRetry: cubit.started),
                    HomeStatus.ready when state.maps.isEmpty =>
                      const SizedBox.shrink(),
                    HomeStatus.ready => _RecentMaps(
                      maps: state.maps,
                      exportMode: capabilities.exportMode,
                    ),
                  },
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const new({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: Column(
        children: [
          Icon(
            Icons.blur_on,
            size: 96,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: spacing.md),
          Text(
            l10n.homeEmptyTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.sm),
          Text(
            l10n.homeEmptyBody,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const new({required this.onOpenFile});

  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: Text(l10n.homeNewAnalysis),
          onPressed: () => const NewAnalysisRoute().go(context),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_open),
          label: Text(l10n.homeOpenFile),
          onPressed: onOpenFile,
        ),
        TextButton.icon(
          icon: const Icon(Icons.view_in_ar),
          label: Text(l10n.homeOpenSample),
          onPressed: () => const ViewerRoute().go(context),
        ),
      ],
    );
  }
}

class _RecentMaps extends StatelessWidget {
  const new({required this.maps, required this.exportMode});

  final List<CodeMapSummary> maps;
  final ExportMode exportMode;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final cubit = context.read<HomeCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.homeRecentTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(height: spacing.sm),
        for (final map in maps)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: RecentMapTile(
              summary: map,
              exportMode: exportMode,
              onOpen: () => ViewerRoute(id: map.id).go(context),
              onExport: () => cubit.exported(map.id),
              onDelete: () => cubit.deleted(map.id),
            ),
          ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const new({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Text(l10n.homeLoadFailed, textAlign: TextAlign.center),
        SizedBox(height: context.spacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text(l10n.analysisRetry),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
