import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Asks whether to cancel the running analysis.
abstract final class CancelAnalysisDialog {
  /// Shows the dialog; true when the user confirms the cancellation.
  static Future<bool> show(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.analysisCancelTitle),
        content: Text(l10n.analysisCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.analysisCancelKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.analysisCancelConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
