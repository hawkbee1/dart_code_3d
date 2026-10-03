/// The build flavor: development adds debugging tools.
enum AppFlavor {
  /// Local development: debug overlay, opening local files by path.
  development,

  /// Pre-release builds.
  staging,

  /// Store builds.
  production,
}
