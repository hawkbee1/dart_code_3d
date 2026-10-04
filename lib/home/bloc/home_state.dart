part of 'home_cubit.dart';

/// Whether the stored maps are known.
enum HomeStatus {
  /// Being read.
  loading,

  /// Listed.
  ready,

  /// The store could not be read.
  failure,
}

/// What the home screen shows.
final class HomeState extends Equatable {
  /// Creates the state.
  const new({
    this.status = HomeStatus.loading,
    this.maps = const [],
    this.notice,
  });

  /// Whether [maps] is known.
  final HomeStatus status;

  /// The stored maps, newest first.
  final List<CodeMapSummary> maps;

  /// The last thing the user should be told, shown once.
  final HomeNotice? notice;

  /// A copy with changes.
  HomeState copyWith({
    HomeStatus? status,
    List<CodeMapSummary>? maps,
    HomeNotice? notice,
  }) => HomeState(
    status: status ?? this.status,
    maps: maps ?? this.maps,
    notice: notice ?? this.notice,
  );

  @override
  List<Object?> get props => [status, maps, notice];
}

/// Something to tell the user once. The [serial] makes two equal notices
/// different, so each one is shown.
sealed class HomeNotice extends Equatable {
  const new({required this.serial});

  /// Counts the notices.
  final int serial;

  @override
  List<Object?> get props => [serial];
}

/// A map was deleted: [file] can be put back.
final class HomeMapDeleted extends HomeNotice {
  const new(this.file, {required super.serial});

  /// The deleted map.
  final CodeMapFile file;
}

/// An operation failed with [failure].
final class HomeFailed extends HomeNotice {
  const new(this.failure, {required super.serial});

  /// What failed.
  final BuildFailure failure;

  @override
  List<Object?> get props => [...super.props, failure];
}

/// Sharing or saving a map failed.
final class HomeExportFailed extends HomeNotice {
  const new({required super.serial});
}
