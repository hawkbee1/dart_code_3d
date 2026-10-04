part of 'viewer_bloc.dart';

/// Something happened in the viewer.
sealed class ViewerEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The viewer was opened on [source].
final class ViewerOpened extends ViewerEvent {
  /// Creates the event.
  const new(this.source);

  /// Where the code map is read from.
  final CodeMapSource source;

  @override
  List<Object?> get props => [source];
}

/// The camera entered [containerId] (the world when null).
final class ViewerContainerChanged extends ViewerEvent {
  /// Creates the event.
  const new(this.containerId);

  /// The container the camera is in.
  final String? containerId;

  @override
  List<Object?> get props => [containerId];
}

/// The user selected [nodeId] (nothing when null).
final class ViewerNodeSelected extends ViewerEvent {
  /// Creates the event.
  const new(this.nodeId);

  /// The selected node.
  final String? nodeId;

  @override
  List<Object?> get props => [nodeId];
}

/// The user chose to show only the links of the selected node, or all again.
final class ViewerFocusToggled extends ViewerEvent {
  /// Creates the event.
  const new();
}

/// The user switched between interior and window view.
final class ViewerViewModeToggled extends ViewerEvent {
  /// Creates the event.
  const new();
}

/// The user showed or hid the links of [kind].
final class ViewerLinkKindToggled extends ViewerEvent {
  /// Creates the event.
  const new(this.kind);

  /// The link kind toggled.
  final LinkKind kind;

  @override
  List<Object?> get props => [kind];
}

/// The user showed or hid the labels.
final class ViewerLabelsToggled extends ViewerEvent {
  /// Creates the event.
  const new();
}
