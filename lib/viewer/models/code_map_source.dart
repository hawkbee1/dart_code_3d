import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Where the viewer reads a code map from.
sealed class CodeMapSource extends Equatable {
  const new();

  /// The sample map bundled with the app.
  static const sample = AssetCodeMapSource('assets/samples/sample.dc3d');
}

/// A `.dc3d` bundled as an asset.
final class AssetCodeMapSource extends CodeMapSource {
  /// Creates the source of the asset at [path].
  const new(this.path);

  /// The asset key.
  final String path;

  @override
  List<Object?> get props => [path];
}

/// A `.dc3d` or `.fscene` already in memory (a file the user picked).
final class BytesCodeMapSource extends CodeMapSource {
  /// Creates the source of [bytes] named [name].
  const new(this.name, this.bytes);

  /// The file name.
  final String name;

  /// The file content.
  final Uint8List bytes;

  @override
  List<Object?> get props => [name, bytes];
}

/// A `.dc3d` on the local disk (native platforms, development flavor only:
/// `--dart-define=DC3D_OPEN=<path>`).
final class LocalFileCodeMapSource extends CodeMapSource {
  /// Creates the source of the file at [path].
  const new(this.path);

  /// The file path.
  final String path;

  @override
  List<Object?> get props => [path];
}
