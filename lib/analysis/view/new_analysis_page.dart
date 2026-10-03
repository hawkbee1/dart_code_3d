import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder until session 15 (source choice, progress, cancel).
class NewAnalysisPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newAnalysisTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: Text(
            l10n.newAnalysisComingSoon,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
