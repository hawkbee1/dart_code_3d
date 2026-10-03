import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppTheme, () {
    test('carries the spacing and 3D world colors of each brightness', () {
      expect(AppTheme.light.extension<AppSpacing>(), const AppSpacing());
      expect(
        AppTheme.light.extension<CodeWorldColors>(),
        CodeWorldColors.light,
      );
      expect(AppTheme.dark.extension<CodeWorldColors>(), CodeWorldColors.dark);
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    });

    testWidgets('is reachable through BuildContext extensions', (tester) async {
      late AppSpacing spacing;
      late CodeWorldColors colors;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            spacing = context.spacing;
            colors = context.worldColors;
            return const SizedBox();
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expect(spacing.md, 16);
      expect(colors, CodeWorldColors.dark);
    });
  });

  group(AppSpacing, () {
    test('copies and interpolates', () {
      const spacing = AppSpacing();

      expect(spacing.copyWith(md: 20).md, 20);
      expect(spacing.copyWith().sm, spacing.sm);
      expect(spacing.copyWith(xs: 1, sm: 2, md: 3, lg: 4, xl: 5).lg, 4);
      expect(spacing.lerp(spacing.copyWith(xl: 40), 0.5).xl, 36);
      expect(spacing.lerp(null, 0.5), same(spacing));
    });
  });

  group(CodeWorldColors, () {
    test('has a color for every node and link kind', () {
      for (final colors in [CodeWorldColors.light, CodeWorldColors.dark]) {
        expect(colors.nodes.keys, containsAll(CodeNodeKind.values));
        expect(colors.links.keys, containsAll(LinkKind.values));
      }
    });

    test('copies and interpolates', () {
      const light = CodeWorldColors.light;

      expect(light.copyWith().background, light.background);
      expect(
        light
            .copyWith(
              background: const Color(0xFF000000),
              nodes: const {},
              links: const {},
              selection: const Color(0xFF111111),
            )
            .selection,
        const Color(0xFF111111),
      );
      expect(light.lerp(CodeWorldColors.dark, 0).background, light.background);
      expect(light.lerp(null, 0.5), light);
    });
  });
}
