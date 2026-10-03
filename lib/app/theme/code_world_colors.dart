import 'package:code_graph/code_graph.dart';
import 'package:material_ui/material_ui.dart';

/// Colors of the 3D world, following the light or dark theme.
class CodeWorldColors extends ThemeExtension<CodeWorldColors> {
  /// Creates the colors.
  const new({
    required this.background,
    required this.nodes,
    required this.links,
    required this.selection,
  });

  /// Light theme colors.
  static const light = CodeWorldColors(
    background: Color(0xFFF4F6FA),
    nodes: {
      CodeNodeKind.classDecl: Color(0xFF3473D9),
      CodeNodeKind.mixinDecl: Color(0xFF8C59D9),
      CodeNodeKind.enumDecl: Color(0xFF26A699),
      CodeNodeKind.extensionDecl: Color(0xFFD98C33),
      CodeNodeKind.extensionTypeDecl: Color(0xFFCC668C),
      CodeNodeKind.method: Color(0xFF59B359),
      CodeNodeKind.constructor: Color(0xFFD9BF40),
      CodeNodeKind.getter: Color(0xFF73BFBF),
      CodeNodeKind.setter: Color(0xFFBF7373),
      CodeNodeKind.function: Color(0xFF4099E6),
      CodeNodeKind.ghostParent: Color(0xFFB3B3BF),
      CodeNodeKind.externalPackage: Color(0xFF737380),
    },
    links: {
      LinkKind.call: Color(0xFF5A6B87),
      LinkKind.import: Color(0xFF9AA5B8),
      LinkKind.implementsLink: Color(0xFF8C59D9),
      LinkKind.mixinLink: Color(0xFF26A699),
      LinkKind.extendsExternal: Color(0xFF737380),
    },
    selection: Color(0xFFFF8A00),
  );

  /// Dark theme colors.
  static const dark = CodeWorldColors(
    background: Color(0xFF10131A),
    nodes: {
      CodeNodeKind.classDecl: Color(0xFF6FA0F0),
      CodeNodeKind.mixinDecl: Color(0xFFB38CF0),
      CodeNodeKind.enumDecl: Color(0xFF4FD1C2),
      CodeNodeKind.extensionDecl: Color(0xFFF0B060),
      CodeNodeKind.extensionTypeDecl: Color(0xFFE88FB0),
      CodeNodeKind.method: Color(0xFF85D685),
      CodeNodeKind.constructor: Color(0xFFF0DA6A),
      CodeNodeKind.getter: Color(0xFF8FDADA),
      CodeNodeKind.setter: Color(0xFFDA8F8F),
      CodeNodeKind.function: Color(0xFF6FB8F5),
      CodeNodeKind.ghostParent: Color(0xFF7A7A8A),
      CodeNodeKind.externalPackage: Color(0xFF9A9AA8),
    },
    links: {
      LinkKind.call: Color(0xFFA8B6CE),
      LinkKind.import: Color(0xFF66708A),
      LinkKind.implementsLink: Color(0xFFB38CF0),
      LinkKind.mixinLink: Color(0xFF4FD1C2),
      LinkKind.extendsExternal: Color(0xFF9A9AA8),
    },
    selection: Color(0xFFFFB050),
  );

  /// Background of the 3D view.
  final Color background;

  /// Sphere color of each node kind.
  final Map<CodeNodeKind, Color> nodes;

  /// Line color of each link kind.
  final Map<LinkKind, Color> links;

  /// Highlight of the selected sphere.
  final Color selection;

  @override
  CodeWorldColors copyWith({
    Color? background,
    Map<CodeNodeKind, Color>? nodes,
    Map<LinkKind, Color>? links,
    Color? selection,
  }) => CodeWorldColors(
    background: background ?? this.background,
    nodes: nodes ?? this.nodes,
    links: links ?? this.links,
    selection: selection ?? this.selection,
  );

  @override
  CodeWorldColors lerp(CodeWorldColors? other, double t) {
    if (other == null) return this;
    return CodeWorldColors(
      background: Color.lerp(background, other.background, t)!,
      nodes: {
        for (final kind in CodeNodeKind.values)
          kind: Color.lerp(nodes[kind], other.nodes[kind], t)!,
      },
      links: {
        for (final kind in LinkKind.values)
          kind: Color.lerp(links[kind], other.links[kind], t)!,
      },
      selection: Color.lerp(selection, other.selection, t)!,
    );
  }
}
