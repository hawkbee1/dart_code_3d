import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../test_driver/image_compare.dart';

/// A [width]×[height] PNG filled with grey [value], with [changed] pixels set
/// to grey [changedValue].
Uint8List _png(
  int width,
  int height, {
  int value = 100,
  int changed = 0,
  int changedValue = 200,
}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgba8(value, value, value, 255));
  for (var i = 0; i < changed; i++) {
    image.setPixel(
      i % width,
      i ~/ width,
      img.ColorRgba8(changedValue, changedValue, changedValue, 255),
    );
  }
  return img.encodePng(image);
}

void main() {
  group('compareImages', () {
    test('passes identical images', () {
      final result = compareImages(_png(20, 20), _png(20, 20));

      expect(result.passed, isTrue);
      expect(result.differingRatio, 0);
      expect(result.diffPng, isNotNull);
    });

    test('ignores channel differences within the tolerance', () {
      final result = compareImages(_png(20, 20, value: 108), _png(20, 20));

      expect(result.passed, isTrue);
    });

    test('passes when few enough pixels differ', () {
      // 2 of 400 pixels = 0.5%, the default limit.
      final result = compareImages(_png(20, 20, changed: 2), _png(20, 20));

      expect(result.passed, isTrue);
      expect(result.differingRatio, 0.005);
    });

    test('fails when too many pixels differ and paints them red', () {
      final result = compareImages(_png(20, 20, changed: 40), _png(20, 20));

      expect(result.passed, isFalse);
      expect(result.differingRatio, 0.1);
      expect(result.message, contains('10.000% of pixels differ'));
      final diff = img.decodePng(result.diffPng!)!;
      expect(diff.getPixel(0, 0).r, 255);
      expect(diff.getPixel(0, 0).g, 0);
      expect(diff.getPixel(19, 19).r, 100);
    });

    test('fails when the sizes differ', () {
      final result = compareImages(_png(20, 20), _png(10, 20));

      expect(result.passed, isFalse);
      expect(
        result.message,
        contains('size 20x20 differs from baseline 10x20'),
      );
      expect(result.diffPng, isNull);
    });

    test('fails when a PNG cannot be decoded', () {
      final result = compareImages(Uint8List(4), _png(20, 20));

      expect(result.passed, isFalse);
      expect(result.message, 'could not decode one of the PNGs');
    });
  });
}
