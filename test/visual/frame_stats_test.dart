import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/visual/frame_stats.dart';

const ({int r, int g, int b}) _clear = (r: 10, g: 20, b: 30);

/// A [width]×[height] RGBA frame filled with [_clear], with [paint] applied.
Uint8List _frame(
  int width,
  int height, [
  void Function(Uint8List rgba, int width)? paint,
]) {
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < rgba.length; i += 4) {
    rgba
      ..[i] = _clear.r
      ..[i + 1] = _clear.g
      ..[i + 2] = _clear.b
      ..[i + 3] = 255;
  }
  paint?.call(rgba, width);
  return rgba;
}

void _setPixel(Uint8List rgba, int width, int x, int y, int value) {
  final i = (y * width + x) * 4;
  rgba
    ..[i] = value
    ..[i + 1] = value
    ..[i + 2] = value;
}

void main() {
  group(FrameStats, () {
    test('reports an empty frame as clear with no coverage', () {
      final stats = FrameStats.of(
        _frame(8, 8),
        width: 8,
        height: 8,
        clear: _clear,
      );

      expect(stats.cornersClear, isTrue);
      expect(stats.centerCoverage, 0);
      expect(stats.foregroundLuma, 0);
    });

    test('measures the coverage and luma of content in the center', () {
      // The center of an 8x8 frame is the 4x4 block from (2,2) to (5,5).
      final rgba = _frame(8, 8, (rgba, width) {
        for (var y = 2; y < 6; y++) {
          for (var x = 2; x < 4; x++) {
            _setPixel(rgba, width, x, y, 200);
          }
        }
      });

      final stats = FrameStats.of(rgba, width: 8, height: 8, clear: _clear);

      expect(stats.cornersClear, isTrue);
      expect(stats.centerCoverage, 0.5);
      expect(stats.foregroundLuma, closeTo(200, 0.01));
    });

    test('reports corners that are not the background', () {
      final rgba = _frame(8, 8, (rgba, width) {
        _setPixel(rgba, width, 7, 7, 255);
      });

      final stats = FrameStats.of(rgba, width: 8, height: 8, clear: _clear);

      expect(stats.cornersClear, isFalse);
    });

    test('treats pixels within the tolerance as background', () {
      final rgba = _frame(8, 8, (rgba, width) {
        final i = (3 * width + 3) * 4;
        rgba[i] = _clear.r + 6;
      });

      final stats = FrameStats.of(rgba, width: 8, height: 8, clear: _clear);

      expect(stats.centerCoverage, 0);
    });

    test('describes itself for the test log', () {
      const stats = FrameStats(
        cornersClear: true,
        centerCoverage: 0.25,
        foregroundLuma: 120,
      );

      expect(
        stats.toString(),
        'cornersClear=true centerCoverage=0.250 foregroundLuma=120.0',
      );
    });
  });
}
