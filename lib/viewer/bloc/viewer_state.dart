part of 'viewer_bloc.dart';

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
    this.focusOnSelected = false,
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

  /// Whether only the links of the selected node are drawn.
  final bool focusOnSelected;

  /// What is drawn: derived from the other fields, computed once per state.
  VisibleWorld get visible => _visible[this] ??= resolveVisibility(
    index: VisibilityIndex.of(map),
    containerId: currentContainerId,
    mode: viewMode,
    linkKinds: visibleLinkKinds,
    selectedId: focusOnSelected ? selectedId : null,
  );

  // One visible world per state (states are immutable).
  static final _visible = Expando<VisibleWorld>('visible world');

  /// A copy with the given fields replaced. Pass a function for the
  /// nullable ids, so they can be cleared.
  ViewerReady copyWith({
    String? Function()? currentContainerId,
    String? Function()? selectedId,
    ViewMode? viewMode,
    Set<LinkKind>? visibleLinkKinds,
    bool? labelsOn,
    bool? focusOnSelected,
  }) => ViewerReady(
    map: map,
    currentContainerId: currentContainerId != null
        ? currentContainerId()
        : this.currentContainerId,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    viewMode: viewMode ?? this.viewMode,
    visibleLinkKinds: visibleLinkKinds ?? this.visibleLinkKinds,
    labelsOn: labelsOn ?? this.labelsOn,
    focusOnSelected: focusOnSelected ?? this.focusOnSelected,
  );

  @override
  List<Object?> get props => [
    map,
    currentContainerId,
    selectedId,
    viewMode,
    visibleLinkKinds,
    labelsOn,
    focusOnSelected,
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
