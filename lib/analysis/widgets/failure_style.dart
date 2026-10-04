import 'package:code_map_repository/code_map_repository.dart';
import 'package:material_ui/material_ui.dart';

/// How a failure looks and what can be done about it.
extension FailureKindStyle on BuildFailureKind {
  /// Whether trying the same thing again may work (a flaky network, a rate
  /// limit, a full disk) as opposed to needing another source.
  bool get retryable => switch (this) {
    BuildFailureKind.network ||
    BuildFailureKind.rateLimited ||
    BuildFailureKind.storage ||
    BuildFailureKind.analysisError => true,
    _ => false,
  };

  /// The icon of the failure screen.
  IconData get icon => switch (this) {
    BuildFailureKind.sourceNotFound => Icons.folder_off_outlined,
    BuildFailureKind.invalidGitUrl => Icons.link_off,
    BuildFailureKind.privateOrMissingRepo => Icons.lock_outline,
    BuildFailureKind.rateLimited => Icons.hourglass_top,
    BuildFailureKind.network => Icons.cloud_off,
    BuildFailureKind.invalidArchive => Icons.folder_zip_outlined,
    BuildFailureKind.unsupportedOnWeb => Icons.web_asset_off,
    BuildFailureKind.invalidFile => Icons.broken_image_outlined,
    BuildFailureKind.storage => Icons.sd_card_alert_outlined,
    BuildFailureKind.analysisError ||
    BuildFailureKind.cancelled => Icons.error_outline,
  };
}
