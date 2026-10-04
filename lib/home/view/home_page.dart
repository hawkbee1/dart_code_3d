import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The first screen: recent code maps (session 15) and the main actions.
class HomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(spacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                SizedBox(height: spacing.lg),
                Wrap(
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
                      onPressed: () => const NewAnalysisRoute().go(context),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.view_in_ar),
                      label: Text(l10n.homeOpenSample),
                      onPressed: () => const ViewerRoute().go(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
