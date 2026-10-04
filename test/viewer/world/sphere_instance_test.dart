import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Color;
import 'package:vector_math/vector_math.dart';

import '../../helpers/code_maps.dart';

void main() {
  group('sphereInstances', () {
    test('draws the top level, colored by kind', () {
      final map = worldMap();

      final instances = sphereInstances(
        map,
        worldPositions(map),
        CodeWorldColors.light,
      );

      expect(instances.map((i) => i.nodeId), ['main', 'A', 'pkg']);
      expect(instances[1].radius, 2);
      expect(
        instances[1].color,
        linearColor(CodeWorldColors.light.nodes[map.graph.nodes['A']!.kind]!),
      );
    });

    test('draws the children of a container', () {
      final map = worldMap();

      final instances = sphereInstances(
        map,
        worldPositions(map),
        CodeWorldColors.dark,
        containerId: 'A',
      );

      expect(instances.single.nodeId, 'A.m');
      expect(instances.single.center, Vector3(5, 0, 0));
    });
  });

  group(SphereInstance, () {
    test('scales a unit sphere to its radius at its center', () {
      final instance = SphereInstance(
        nodeId: 'n',
        center: Vector3(1, 2, 3),
        radius: 2,
        color: Vector4.all(1),
      );

      final point = instance.transform.transformed3(Vector3(1, 0, 0));

      expect(point, Vector3(3, 2, 3));
      expect(
        instance,
        SphereInstance(
          nodeId: 'n',
          center: Vector3(1, 2, 3),
          radius: 2,
          color: Vector4.all(1),
        ),
      );
    });
  });

  group('linearColor', () {
    test('converts sRGB to linear', () {
      expect(linearColor(const Color(0xFFFFFFFF)), Vector4(1, 1, 1, 1));
      expect(linearColor(const Color(0x00000000)), Vector4(0, 0, 0, 0));
      final mid = linearColor(const Color(0xFF808080));
      expect(mid.r, closeTo(0.2158, 1e-3));
      expect(linearColor(const Color(0xFF050505)).r, closeTo(0.0015, 1e-4));
    });
  });
}
