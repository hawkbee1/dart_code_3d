// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$homeRoute];

RouteBase get $homeRoute => GoRouteData.$route(
  path: '/',
  name: 'home',
  hasOverriddenOnExit: false,
  factory: $HomeRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'settings',
      name: 'settings',
      hasOverriddenOnExit: false,
      factory: $SettingsRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'new-analysis',
      name: 'newAnalysis',
      hasOverriddenOnExit: false,
      factory: $NewAnalysisRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'viewer',
      name: 'viewer',
      hasOverriddenOnExit: false,
      factory: $ViewerRoute._fromState,
    ),
  ],
);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $NewAnalysisRoute on GoRouteData {
  static NewAnalysisRoute _fromState(GoRouterState state) =>
      const NewAnalysisRoute();

  @override
  String get location => GoRouteData.$location('/new-analysis');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ViewerRoute on GoRouteData {
  static ViewerRoute _fromState(GoRouterState state) => ViewerRoute(
    id: state.uri.queryParameters['id'],
    file: state.uri.queryParameters['file'],
  );

  ViewerRoute get _self => this as ViewerRoute;

  @override
  String get location => GoRouteData.$location(
    '/viewer',
    queryParams: {
      if (_self.id != null) 'id': _self.id,
      if (_self.file != null) 'file': _self.file,
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
