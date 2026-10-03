part of 'viewer_bloc.dart';

/// What is seen from inside a sphere.
enum ViewMode {
  /// Only the inside of the current sphere.
  interior,

  /// The inside, plus the outer world through a transparent shell.
  window,
}

/// The state of the viewer.
sealed class ViewerState extends Equatable {
  const new();
}

/// The code map is being read.
final class ViewerLoading extends ViewerState {
  /// Creates the state.
  const new();

  @override
  List<Object?> get props => [];
}

/// The code map is open.
final class ViewerReady extends ViewerState {
  /// Creates the state.
  const new({
    required this.map,
    this.currentContainerId,
    this.selectedId,
    this.viewMode = ViewMode.interior,
    this.visibleLinkKinds = const {...LinkKind.values},
    this.labelsOn = true,
  });

  /// The open map.
  final CodeMap map;

  /// The sphere the camera is in (the world when null).
  final String? currentContainerId;

  /// The selected node, if any.
  final String? selectedId;

  /// Interior or window view.
  final ViewMode viewMode;

  /// The link kinds drawn.
  final Set<LinkKind> visibleLinkKinds;

  /// Whether labels are drawn.
  final bool labelsOn;

  /// A copy with the given fields replaced. Pass a function for the
  /// nullable ids, so they can be cleared.
  ViewerReady copyWith({
    String? Function()? currentContainerId,
    String? Function()? selectedId,
    ViewMode? viewMode,
    Set<LinkKind>? visibleLinkKinds,
    bool? labelsOn,
  }) => ViewerReady(
    map: map,
    currentContainerId: currentContainerId != null
        ? currentContainerId()
        : this.currentContainerId,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    viewMode: viewMode ?? this.viewMode,
    visibleLinkKinds: visibleLinkKinds ?? this.visibleLinkKinds,
    labelsOn: labelsOn ?? this.labelsOn,
  );

  @override
  List<Object?> get props => [
    map,
    currentContainerId,
    selectedId,
    viewMode,
    visibleLinkKinds,
    labelsOn,
  ];
}

/// The code map could not be opened.
final class ViewerFailure extends ViewerState {
  /// Creates the state.
  const new(this.details);

  /// Technical details, shown under the localized message.
  final String details;

  @override
  List<Object?> get props => [details];
}
