import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:settings_repository/settings_repository.dart';

/// Localized texts of the rules the app knows. A rule added to the engine
/// catalog later still shows, with the catalog's English texts.
extension RuleTexts on AppLocalizations {
  /// Title of [rule].
  String ruleTitle(RuleParameter<Object> rule) =>
      _rule(rule.id)?.$1 ?? rule.title;

  /// Description of [rule].
  String ruleDescription(RuleParameter<Object> rule) =>
      _rule(rule.id)?.$2 ?? rule.description;

  /// Title of [option].
  String optionTitle(RuleOption option) =>
      switch (option.value) {
        'skip' => optionSkip,
        'uniqueName' => optionUniqueName,
        'all' => optionAll,
        'method' => optionMethod,
        'constructor' => optionConstructor,
        'getter' => optionGetter,
        'setter' => optionSetter,
        'parseOnly' => optionParseOnly,
        'fullResolution' => optionFullResolution,
        _ => null,
      } ??
      option.title;

  /// Note of a disabled [option].
  String? optionNote(RuleOption option) =>
      option.value == 'fullResolution' ? optionFullResolutionNote : option.note;

  /// Title of [group].
  String groupTitle(RuleGroup group) => switch (group) {
    RuleGroup.files => ruleGroupFiles,
    RuleGroup.links => ruleGroupLinks,
    RuleGroup.nodes => ruleGroupNodes,
    RuleGroup.entry => ruleGroupEntry,
    RuleGroup.analysis => ruleGroupAnalysis,
  };

  (String, String)? _rule(String id) => switch (id) {
    RuleIds.excludeGenerated => (
      ruleExcludeGeneratedTitle,
      ruleExcludeGeneratedDescription,
    ),
    RuleIds.generatedPatterns => (
      ruleGeneratedPatternsTitle,
      ruleGeneratedPatternsDescription,
    ),
    RuleIds.excludeTests => (
      ruleExcludeTestsTitle,
      ruleExcludeTestsDescription,
    ),
    RuleIds.extraExcludes => (
      ruleExtraExcludesTitle,
      ruleExtraExcludesDescription,
    ),
    RuleIds.linksCalls => (ruleCallsTitle, ruleCallsDescription),
    RuleIds.linksImports => (ruleImportsTitle, ruleImportsDescription),
    RuleIds.linksImplements => (ruleImplementsTitle, ruleImplementsDescription),
    RuleIds.linksMixins => (ruleMixinsTitle, ruleMixinsDescription),
    RuleIds.ambiguousCalls => (
      ruleAmbiguousCallsTitle,
      ruleAmbiguousCallsDescription,
    ),
    RuleIds.externalPackages => (
      ruleExternalPackagesTitle,
      ruleExternalPackagesDescription,
    ),
    RuleIds.dartSdk => (ruleDartSdkTitle, ruleDartSdkDescription),
    RuleIds.ghostParents => (
      ruleGhostParentsTitle,
      ruleGhostParentsDescription,
    ),
    RuleIds.includePrivate => (rulePrivateTitle, rulePrivateDescription),
    RuleIds.memberKinds => (ruleMemberKindsTitle, ruleMemberKindsDescription),
    RuleIds.entryPoint => (ruleEntryPointTitle, ruleEntryPointDescription),
    RuleIds.resolutionMode => (
      ruleResolutionModeTitle,
      ruleResolutionModeDescription,
    ),
    _ => null,
  };
}
