import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';

/// Logs what the blocs do, by type only.
///
/// States hold the user's code: a decoded map, the bytes of a picked zip. In
/// debug builds `Equatable` prints every field, so logging a state would dump
/// all of it (and take seconds on a big map). Only the types are logged.
class AppBlocObserver extends BlocObserver {
  /// Creates the observer; [logger] is injectable for tests.
  const new({this.logger = _log});

  /// Where messages go (the developer log by default).
  final void Function(String message, {Object? error, StackTrace? stackTrace})
  logger;

  static void _log(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(message, error: error, stackTrace: stackTrace);

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    logger(
      '${bloc.runtimeType}: ${change.currentState.runtimeType} → '
      '${change.nextState.runtimeType}',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    logger(
      '${bloc.runtimeType} failed',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}
