import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The localized names of node kinds and link resolutions.
extension NodeKindTexts on AppLocalizations {
  /// The name of [kind] ("Class", "Method"…).
  String nodeKindLabel(CodeNodeKind kind) => switch (kind) {
    CodeNodeKind.classDecl => nodeKindClass,
    CodeNodeKind.mixinDecl => nodeKindMixin,
    CodeNodeKind.enumDecl => nodeKindEnum,
    CodeNodeKind.extensionDecl => nodeKindExtension,
    CodeNodeKind.extensionTypeDecl => nodeKindExtensionType,
    CodeNodeKind.method => nodeKindMethod,
    CodeNodeKind.constructor => nodeKindConstructor,
    CodeNodeKind.getter => nodeKindGetter,
    CodeNodeKind.setter => nodeKindSetter,
    CodeNodeKind.function => nodeKindFunction,
    CodeNodeKind.ghostParent => nodeKindGhostParent,
    CodeNodeKind.externalPackage => nodeKindExternalPackage,
  };

  /// How far to trust a link of [resolution] ("exact", "ambiguous"…).
  String resolutionLabel(LinkResolution resolution) => switch (resolution) {
    LinkResolution.exact => resolutionExact,
    LinkResolution.byName => resolutionByName,
    LinkResolution.ambiguous => resolutionAmbiguous,
    LinkResolution.external => resolutionExternal,
  };
}

/// The icon of a node kind.
IconData nodeKindIcon(CodeNodeKind kind) => switch (kind) {
  CodeNodeKind.classDecl => Icons.data_object,
  CodeNodeKind.mixinDecl => Icons.layers_outlined,
  CodeNodeKind.enumDecl => Icons.list_alt_outlined,
  CodeNodeKind.extensionDecl => Icons.extension_outlined,
  CodeNodeKind.extensionTypeDecl => Icons.extension,
  CodeNodeKind.method => Icons.settings_outlined,
  CodeNodeKind.constructor => Icons.build_outlined,
  CodeNodeKind.getter => Icons.download_outlined,
  CodeNodeKind.setter => Icons.upload_outlined,
  CodeNodeKind.function => Icons.functions,
  CodeNodeKind.ghostParent => Icons.cloud_outlined,
  CodeNodeKind.externalPackage => Icons.inventory_2_outlined,
};
