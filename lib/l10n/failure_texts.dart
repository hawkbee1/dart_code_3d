import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/l10n/gen/app_localizations.dart';

/// What a failure says to the user, by its kind (the repository's own
/// messages are in English only).
extension FailureTexts on AppLocalizations {
  /// The title of a failure of [kind].
  String failureTitle(BuildFailureKind kind) => switch (kind) {
    BuildFailureKind.sourceNotFound => failureSourceNotFoundTitle,
    BuildFailureKind.invalidGitUrl => failureInvalidGitUrlTitle,
    BuildFailureKind.privateOrMissingRepo => failurePrivateOrMissingRepoTitle,
    BuildFailureKind.rateLimited => failureRateLimitedTitle,
    BuildFailureKind.network => failureNetworkTitle,
    BuildFailureKind.invalidArchive => failureInvalidArchiveTitle,
    BuildFailureKind.unsupportedOnWeb => failureUnsupportedOnWebTitle,
    BuildFailureKind.invalidFile => failureInvalidFileTitle,
    BuildFailureKind.analysisError => failureAnalysisErrorTitle,
    BuildFailureKind.storage => failureStorageTitle,
    BuildFailureKind.cancelled => failureCancelledTitle,
  };

  /// What a failure of [kind] means and what to do.
  String failureBody(BuildFailureKind kind) => switch (kind) {
    BuildFailureKind.sourceNotFound => failureSourceNotFoundBody,
    BuildFailureKind.invalidGitUrl => failureInvalidGitUrlBody,
    BuildFailureKind.privateOrMissingRepo => failurePrivateOrMissingRepoBody,
    BuildFailureKind.rateLimited => failureRateLimitedBody,
    BuildFailureKind.network => failureNetworkBody,
    BuildFailureKind.invalidArchive => failureInvalidArchiveBody,
    BuildFailureKind.unsupportedOnWeb => failureUnsupportedOnWebBody,
    BuildFailureKind.invalidFile => failureInvalidFileBody,
    BuildFailureKind.analysisError => failureAnalysisErrorBody,
    BuildFailureKind.storage => failureStorageBody,
    BuildFailureKind.cancelled => failureCancelledBody,
  };
}
