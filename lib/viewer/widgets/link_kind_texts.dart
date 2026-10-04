import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/l10n/l10n.dart';

/// The localized names of link kinds.
extension LinkKindTexts on AppLocalizations {
  /// The name of [kind] in the link legend.
  String linkKindLabel(LinkKind kind) => switch (kind) {
    LinkKind.call => viewerLinkCalls,
    LinkKind.import => viewerLinkImports,
    LinkKind.implementsLink => viewerLinkImplements,
    LinkKind.mixinLink => viewerLinkMixins,
    LinkKind.extendsExternal => viewerLinkExtendsExternal,
  };
}
