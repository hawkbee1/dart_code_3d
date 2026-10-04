import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
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

/// `/viewer`: the 3D view (a demo sphere until session 11).
@immutable
class ViewerRoute extends GoRouteData with $ViewerRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ViewerPage();
}
