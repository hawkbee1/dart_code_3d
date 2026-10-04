import 'package:code_graph/code_graph.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// What a user can do with a stored map from the list.
enum RecentMapAction {
  /// Open it in the viewer.
  open,

  /// Share it (phones), save it or download it.
  export,

  /// Delete it.
  delete,
}

/// A stored map in the home list: its name, where it comes from, its size
/// and date; tap to open, a menu or a swipe to delete.
class RecentMapTile extends StatelessWidget {
  const new({
    required this.summary,
    required this.exportMode,
    required this.onOpen,
    required this.onExport,
    required this.onDelete,
    super.key,
  });

  /// The map.
  final CodeMapSummary summary;

  /// How the map leaves the app (names the menu entry).
  final ExportMode exportMode;

  /// Called to open the map.
  final VoidCallback onOpen;

  /// Called to share, save or download the map.
  final VoidCallback onExport;

  /// Called to delete the map.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).format(summary.createdAt.toLocal());
    final spheres = NumberFormat.decimalPattern(locale)
        .format(summary.nodeCount);
    final source = summary.source;
    return Dismissible(
      key: ValueKey(summary.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: spacing.lg),
            child: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onOpen,
          leading: Icon(switch (source) {
            GitDescriptor() => Icons.cloud_download_outlined,
            LocalFolderDescriptor() => Icons.folder_open,
            ZipDescriptor() => Icons.folder_zip_outlined,
          }, color: theme.colorScheme.primary),
          title: Text(
            summary.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Two lines of their own: a long source never hides the size.
              Text(
                _sourceLine(l10n, source),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l10n.homeMapMeta(spheres, date),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<RecentMapAction>(
            tooltip: l10n.homeMapActions(summary.name),
            onSelected: (action) => switch (action) {
              RecentMapAction.open => onOpen(),
              RecentMapAction.export => onExport(),
              RecentMapAction.delete => onDelete(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: RecentMapAction.open,
                child: Text(l10n.homeMapOpen),
              ),
              PopupMenuItem(
                value: RecentMapAction.export,
                child: Text(
                  exportMode == ExportMode.share
                      ? l10n.homeMapShare
                      : l10n.homeMapExport,
                ),
              ),
              PopupMenuItem(
                value: RecentMapAction.delete,
                child: Text(l10n.homeMapDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sourceLine(AppLocalizations l10n, SourceDescriptor source) =>
      switch (source) {
        GitDescriptor(:final url, :final ref) =>
          '${url.replaceFirst(RegExp('^https?://'), '')}'
              '${ref == null ? '' : ' @ $ref'}',
        LocalFolderDescriptor(:final name) => l10n.homeSourceFolder(name),
        ZipDescriptor(:final fileName) => l10n.homeSourceZip(fileName),
      };
}
