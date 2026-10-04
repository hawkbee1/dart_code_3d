import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// How a code map leaves the app.
enum ExportMode {
  /// The system share sheet (phones and tablets).
  share,

  /// A save dialog (desktop).
  saveFile,

  /// A browser download (web).
  download,
}

/// What the platform the app runs on can do. Provided above the app, so
/// widgets never ask `kIsWeb` or `Platform` and can be tested for each
/// platform.
class PlatformCapabilities extends Equatable {
  /// Creates capabilities.
  const new({
    required this.gitSources,
    required this.folderSources,
    required this.persistentStorage,
    required this.exportMode,
  });

  /// Windows, macOS and Linux.
  static const desktop = PlatformCapabilities(
    gitSources: true,
    folderSources: true,
    persistentStorage: true,
    exportMode: ExportMode.saveFile,
  );

  /// Android and iOS. A picked folder is not a path the app can read
  /// (scoped storage), so folders are left out.
  static const mobile = PlatformCapabilities(
    gitSources: true,
    folderSources: false,
    persistentStorage: true,
    exportMode: ExportMode.share,
  );

  /// Browsers: no git download (they block it), no folders, and maps live
  /// in memory.
  static const web = PlatformCapabilities(
    gitSources: false,
    folderSources: false,
    persistentStorage: false,
    exportMode: ExportMode.download,
  );

  /// The capabilities of the platform this app is running on.
  static PlatformCapabilities get current => kIsWeb
      ? web
      : switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS => mobile,
          TargetPlatform.fuchsia ||
          TargetPlatform.linux ||
          TargetPlatform.macOS ||
          TargetPlatform.windows => desktop,
        };

  /// Whether a public git repository can be analyzed.
  final bool gitSources;

  /// Whether a local folder can be analyzed in place.
  final bool folderSources;

  /// Whether stored maps survive a restart.
  final bool persistentStorage;

  /// How a map is shared.
  final ExportMode exportMode;

  @override
  List<Object?> get props => [
    gitSources,
    folderSources,
    persistentStorage,
    exportMode,
  ];
}
