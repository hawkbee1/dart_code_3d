import 'dart:ui' show Rect, Size;

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

LabelCandidate _candidate(
  String id,
  double x,
  double y,
  double z, [
  double radius = 1,
]) => (id: id, text: id, center: Vector3(x, y, z), radius: radius);

void main() {
  group(layoutLabels, () {
    // A 400 px square, 90° field of view, at the origin looking down -Z:
    // a sphere of radius r at depth d is r * 200 / d pixels in radius, and a
    // point at (x, 0, -d) is at 200 + 200 * x / d pixels.
    final camera = ViewCamera(
      position: Vector3.zero(),
      forward: Vector3(0, 0, -1),
      fovY: 3.141592653589793 / 2,
      size: const Size(400, 400),
    );

    List<String> ids(List<PlacedLabel> labels) => [
      for (final l in labels) l.id,
    ];

    test('labels the spheres in front of the camera', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [_candidate('a', 0, 0, -10), _candidate('b', 2, 0, -10)],
      );

      expect(ids(labels), ['a', 'b']);
      expect(labels.first.rect.center.dx, closeTo(200, 1e-9));
      expect(labels.first.rect.center.dy, closeTo(200, 1e-9));
      expect(labels.first.selected, isFalse);
    });

    test('drops what is behind the camera or outside the view', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [
          _candidate('behind', 0, 0, 10),
          _candidate('aside', 50, 0, -10),
          _candidate('ahead', 0, 0, -10),
        ],
      );

      expect(ids(labels), ['ahead']);
    });

    test('drops spheres that are too small, but not the selected one', () {
      // 0.1 at depth 100: 0.2 px in radius.
      final candidates = [
        _candidate('tiny', 30, 0, -100, 0.1),
        _candidate('big', -30, 0, -100, 5),
      ];

      expect(ids(layoutLabels(camera: camera, candidates: candidates)), [
        'big',
      ]);
      expect(
        ids(
          layoutLabels(
            camera: camera,
            candidates: candidates,
            selectedId: 'tiny',
          ),
        ),
        ['tiny', 'big'],
      );
    });

    test('puts the selected one first, then the nearest', () {
      final labels = layoutLabels(
        camera: camera,
        selectedId: 'far',
        candidates: [
          _candidate('near', -3, 0, -10),
          _candidate('far', 3, 0, -30, 3),
          _candidate('middle', 0, 3, -20, 2),
        ],
      );

      expect(ids(labels), ['far', 'near', 'middle']);
      expect(labels.first.selected, isTrue);
      expect(labels.skip(1).any((l) => l.selected), isFalse);
    });

    test('keeps at most the requested number, the nearest ones', () {
      final candidates = [
        for (var i = 0; i < 10; i++) _candidate('n$i', i - 5.0, 0, -10.0 - i),
      ];

      final labels = layoutLabels(
        camera: camera,
        candidates: candidates,
        maxLabels: 3,
        measure: (_) => const Size(10, 10),
      );

      expect(ids(labels), ['n0', 'n1', 'n2']);
    });

    test('skips a farther label that would overlap a nearer one', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [
          _candidate('far', 0.1, 0, -20, 2),
          _candidate('near', 0, 0, -10),
        ],
      );

      expect(ids(labels), ['near']);
    });

    test('breaks distance ties by id', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [_candidate('b', 2, 0, -10), _candidate('a', -2, 0, -10)],
      );

      expect(ids(labels), ['a', 'b']);
    });

    test('keeps a label inside the view', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [
          _candidate('right', 9.9, 0, -10),
          _candidate('left', -9.9, 0, -10),
          _candidate('top', 0, 9.9, -10),
          _candidate('bottom', 0, -9.9, -10),
        ],
      );

      const view = Rect.fromLTWH(0, 0, 400, 400);
      expect(labels, hasLength(4));
      for (final label in labels) {
        expect(view.contains(label.rect.topLeft), isTrue, reason: label.id);
        expect(
          view.contains(label.rect.bottomRight - const Offset(0.01, 0.01)),
          isTrue,
          reason: label.id,
        );
      }
    });

    test('leaves a label wider than the view where it is', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [_candidate('wide', 0, 0, -10)],
        measure: (_) => const Size(500, 24),
      );

      expect(labels.single.rect.width, 500);
    });

    test('uses the measure it is given', () {
      final labels = layoutLabels(
        camera: camera,
        candidates: [_candidate('a', 0, 0, -10)],
        measure: (text) => Size(100.0 + text.length, 30),
      );

      expect(labels.single.rect.size, const Size(101, 30));
    });
  });

  test('estimates a label from its length', () {
    expect(estimateLabelSize('abc'), const Size(35, 24));
    expect(
      estimateLabelSize('abcdef').width,
      greaterThan(estimateLabelSize('abc').width),
    );
  });

  test('placed labels compare by value', () {
    PlacedLabel label() => PlacedLabel(
      id: 'a',
      text: 'a',
      rect: Rect.fromLTWH(0, 0, [10].first.toDouble(), 10),
      selected: [true].first,
    );

    expect(label(), label());
    expect(label().props, hasLength(4));
  });
}
