import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The result of comparing a capture with its baseline.
class ImageComparison {
  const new({
    required this.passed,
    required this.differingRatio,
    required this.message,
    this.diffPng,
  });

  /// Whether the capture matches the baseline within tolerance.
  final bool passed;

  /// Share (0..1) of pixels whose difference exceeds the tolerance.
  final double differingRatio;

  /// Human-readable summary.
  final String message;

  /// The baseline with differing pixels painted red, when sizes match.
  final Uint8List? diffPng;
}

/// Compares two PNGs pixel by pixel.
///
/// A pixel differs when any RGBA channel differs by more than
/// [channelTolerance] (out of 255). The comparison passes when at most
/// [maxDifferingRatio] of the pixels differ. Software rasterizers are
/// deterministic, but anti-aliasing may still move a few edge pixels.
ImageComparison compareImages(
  Uint8List actualPng,
  Uint8List baselinePng, {
  int channelTolerance = 8,
  double maxDifferingRatio = 0.005,
}) {
  final actual = img.decodePng(actualPng);
  final baseline = img.decodePng(baselinePng);
  if (actual == null || baseline == null) {
    return const ImageComparison(
      passed: false,
      differingRatio: 1,
      message: 'could not decode one of the PNGs',
    );
  }
  if (actual.width != baseline.width || actual.height != baseline.height) {
    return ImageComparison(
      passed: false,
      differingRatio: 1,
      message:
          'size ${actual.width}x${actual.height} differs from baseline '
          '${baseline.width}x${baseline.height}',
    );
  }

  final diff = img.Image.from(baseline);
  final red = img.ColorRgba8(255, 0, 0, 255);
  var differing = 0;
  for (var y = 0; y < actual.height; y++) {
    for (var x = 0; x < actual.width; x++) {
      final a = actual.getPixel(x, y);
      final b = baseline.getPixel(x, y);
      final exceeds =
          (a.r - b.r).abs() > channelTolerance ||
          (a.g - b.g).abs() > channelTolerance ||
          (a.b - b.b).abs() > channelTolerance ||
          (a.a - b.a).abs() > channelTolerance;
      if (exceeds) {
        differing++;
        diff.setPixel(x, y, red);
      }
    }
  }
  final ratio = differing / (actual.width * actual.height);
  final passed = ratio <= maxDifferingRatio;
  return ImageComparison(
    passed: passed,
    differingRatio: ratio,
    message:
        '${(ratio * 100).toStringAsFixed(3)}% of pixels differ '
        '(limit ${(maxDifferingRatio * 100).toStringAsFixed(3)}%)',
    diffPng: img.encodePng(diff),
  );
}
