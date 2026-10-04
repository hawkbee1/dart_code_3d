import 'dart:typed_data';

import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(invertedFaces, () {
    // Two triangles sharing an edge, normals pointing up.
    MeshData quad({List<int>? indices, bool normals = true}) => MeshData(
      positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1]),
      vertexCount: 4,
      normals: normals
          ? Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0])
          : null,
      texCoords: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
      indices: indices,
    );

    test('reverses the winding of every triangle', () {
      final inverted = invertedFaces(quad(indices: [0, 1, 2, 0, 2, 3]));

      expect(inverted.indices, [0, 2, 1, 0, 3, 2]);
    });

    test('negates the normals and keeps the vertices', () {
      final source = quad(indices: [0, 1, 2, 0, 2, 3]);

      final inverted = invertedFaces(source);

      expect(inverted.normals, [0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0]);
      expect(inverted.positions, source.positions);
      expect(inverted.texCoords, source.texCoords);
      expect(inverted.vertexCount, 4);
    });

    test('numbers the corners of an unindexed mesh', () {
      final inverted = invertedFaces(
        MeshData(positions: Float32List(9), vertexCount: 3),
      );

      expect(inverted.indices, [0, 2, 1]);
      expect(inverted.normals, isNull);
    });

    test('leaves a partial triangle at the end as it is', () {
      final inverted = invertedFaces(quad(indices: [0, 1, 2, 3, 0]));

      expect(inverted.indices, [0, 2, 1, 3, 0]);
    });

    test('inverting twice gives the original winding and normals', () {
      final source = quad(indices: [0, 1, 2, 0, 2, 3]);

      final twice = invertedFaces(invertedFaces(source));

      expect(twice.indices, source.indices);
      expect(twice.normals, source.normals);
    });
  });
}
