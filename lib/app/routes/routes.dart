import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:dart_code_3d/app/flavor.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'routes.g.dart';

/// `/`: the home screen, parent of every other route (so the app bar shows
/// a back button everywhere else).
@TypedGoRoute<HomeRoute>(
  name: 'home',
  path: '/',
  routes: [
    TypedGoRoute<SettingsRoute>(name: 'settings', path: 'settings'),
    TypedGoRoute<NewAnalysisRoute>(name: 'newAnalysis', path: 'new-analysis'),
    TypedGoRoute<ViewerRoute>(name: 'viewer', path: 'viewer'),
  ],
)
@immutable
class HomeRoute extends GoRouteData with $HomeRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

/// `/settings`.
@immutable
class SettingsRoute extends GoRouteData with $SettingsRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsPage();
}

/// `/new-analysis`.
@immutable
class NewAnalysisRoute extends GoRouteData with $NewAnalysisRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NewAnalysisPage();
}

/// `/viewer`: the 3D view of the stored map [id] (`/viewer?id=<id>`), of
/// the local [file] (`/viewer?file=<path>`, development flavor only), or of
/// the bundled sample.
@immutable
class ViewerRoute extends GoRouteData with $ViewerRoute {
  const new({this.id, this.file});

  /// A map in the app's storage.
  final String? id;

  /// A local `.dc3d` path; ignored outside the development flavor.
  final String? file;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final id = this.id;
    final file = this.file;
    final developer = context.read<AppFlavor>() == AppFlavor.development;
    return ViewerPage(
      source: id != null
          ? StoredCodeMapSource(id)
          : file != null && developer
          ? LocalFileCodeMapSource(file)
          : CodeMapSource.sample,
    );
  }
}
