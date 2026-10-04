// goldenTest tags every test with TestTag.golden.

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

/// [child] on the world background, as over the 3D area.
Widget _overWorld(Widget child) => Builder(
  builder: (context) => Scaffold(
    backgroundColor: context.worldColors.background,
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Align(alignment: AlignmentDirectional.topStart, child: child),
      ),
    ),
  ),
);

void main() {
  group('HUD parts', () {
    goldenTest(
      'a short breadcrumb',
      fileName: 'hud_breadcrumb_short',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => _overWorld(
        Breadcrumb(
          path: const [
            (id: null, name: 'World'),
            (id: 'A', name: 'UserRepository'),
            (id: 'A.B', name: 'CachedUserRepository'),
          ],
          onCrumbTap: (_) {},
        ),
      ),
    );

    goldenTest(
      'a breadcrumb with very long names, cut and wrapped',
      fileName: 'hud_breadcrumb_long',
      builder: () => _overWorld(
        Breadcrumb(
          path: const [
            (id: null, name: 'World'),
            (
              id: 'A',
              name: 'AnExtremelyLongClassNameInAVeryNestedPackageStructure',
            ),
            (id: 'B', name: 'AnotherVeryLongNestedSubclassNameThatKeepsGoing'),
            (id: 'C', name: 'ThirdLevelClassWithAnAbsurdlyLongNameToo'),
            (id: 'D', name: 'Leaf'),
          ],
          onCrumbTap: (_) {},
        ),
      ),
    );

    goldenTest(
      'the link legend with some kinds hidden',
      fileName: 'hud_legend',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => _overWorld(
        Material(
          type: MaterialType.transparency,
          child: LinkLegend(
            kinds: LinkKind.values,
            visibleKinds: const {LinkKind.call, LinkKind.mixinLink},
            onToggle: (_) {},
          ),
        ),
      ),
    );

    goldenTest(
      'the view toggle in both modes',
      fileName: 'hud_view_toggle',
      locales: const [Locale('en'), Locale('fr')],
      builder: () => _overWorld(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ViewModeToggle(mode: ViewMode.interior, onToggle: () {}),
            const SizedBox(height: 16),
            ViewModeToggle(mode: ViewMode.window, onToggle: () {}),
          ],
        ),
      ),
    );
  });
}
