import 'dart:typed_data';

/// Reference-free sanity numbers for a captured frame, to catch a blank,
/// unlit or missing render without comparing against a baseline.
class FrameStats {
  const new({
    required this.cornersClear,
    required this.centerCoverage,
    required this.foregroundLuma,
  });

  /// Computes the stats of an RGBA frame whose background is [clear].
  ///
  /// A pixel is "clear" when every channel is within [tolerance] of [clear].
  /// The center is the middle half of the frame in both directions.
  factory of(
    Uint8List rgba, {
    required int width,
    required int height,
    required ({int r, int g, int b}) clear,
    int tolerance = 6,
  }) {
    bool isClear(int x, int y) {
      final i = (y * width + x) * 4;
      return (rgba[i] - clear.r).abs() <= tolerance &&
          (rgba[i + 1] - clear.g).abs() <= tolerance &&
          (rgba[i + 2] - clear.b).abs() <= tolerance;
    }

    final cornersClear = [
      (0, 0),
      (width - 1, 0),
      (0, height - 1),
      (width - 1, height - 1),
    ].every((c) => isClear(c.$1, c.$2));

    var centerTotal = 0;
    var centerCovered = 0;
    var foreground = 0;
    var lumaSum = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final clearPixel = isClear(x, y);
        final inCenter =
            x >= width ~/ 4 &&
            x < 3 * width ~/ 4 &&
            y >= height ~/ 4 &&
            y < 3 * height ~/ 4;
        if (inCenter) {
          centerTotal++;
          if (!clearPixel) centerCovered++;
        }
        if (!clearPixel) {
          final i = (y * width + x) * 4;
          foreground++;
          lumaSum +=
              0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
        }
      }
    }
    return FrameStats(
      cornersClear: cornersClear,
      centerCoverage: centerTotal == 0 ? 0 : centerCovered / centerTotal,
      foregroundLuma: foreground == 0 ? 0 : lumaSum / foreground,
    );
  }

  /// Whether the four corner pixels show the background.
  final bool cornersClear;

  /// Share (0..1) of non-background pixels in the center of the frame.
  final double centerCoverage;

  /// Mean luma (0..255) of the non-background pixels.
  final double foregroundLuma;

  @override
  String toString() =>
      'cornersClear=$cornersClear '
      'centerCoverage=${centerCoverage.toStringAsFixed(3)} '
      'foregroundLuma=${foregroundLuma.toStringAsFixed(1)}';
}
