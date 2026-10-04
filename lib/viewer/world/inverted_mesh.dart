import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

/// [data] seen from the inside: its normals negated and the winding of every
/// triangle reversed, with the vertices where they were.
///
/// A blended material is always back-face culled, so a dome to look at from
/// within needs its inner faces to be the front ones. (Mirroring the vertices
/// would not do it: `MeshData.transformed` compensates the winding of a
/// mirror, so the result stays an ordinary outward sphere.)
MeshData invertedFaces(MeshData data) {
  final normals = data.normals;
  final source = data.indices;
  final corners = source?.length ?? data.vertexCount;
  final indices = List<int>.generate(corners, (i) => source?[i] ?? i);
  for (var t = 0; t + 2 < corners; t += 3) {
    final second = indices[t + 1];
    indices[t + 1] = indices[t + 2];
    indices[t + 2] = second;
  }
  return MeshData(
    positions: data.positions,
    vertexCount: data.vertexCount,
    normals: normals == null
        ? null
        : (Float32List(normals.length)
            ..setAll(0, [for (final n in normals) -n])),
    texCoords: data.texCoords,
    texCoords1: data.texCoords1,
    colors: data.colors,
    tangents: data.tangents,
    indices: indices,
    primitiveType: data.primitiveType,
    customAttributes: data.customAttributes,
  );
}
