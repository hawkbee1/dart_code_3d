import 'dart:ui' show Offset, Rect, Size;

import 'package:dart_code_3d/viewer/world/view_camera.dart';
import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart';

/// A sphere that may get a label.
typedef LabelCandidate = ({
  String id,
  String text,
  Vector3 center,
  double radius,
});

/// A label placed on the screen.
class PlacedLabel extends Equatable {
  /// Creates a placed label.
  const new({
    required this.id,
    required this.text,
    required this.rect,
    required this.selected,
  });

  /// The node it names.
  final String id;

  /// The text.
  final String text;

  /// Where it is drawn, in view coordinates.
  final Rect rect;

  /// Whether it names the selected node.
  final bool selected;

  @override
  List<Object?> get props => [id, text, rect, selected];
}

/// A rough size of [text] as a label, without measuring it.
Size estimateLabelSize(String text) => Size(text.length * 7.0 + 14, 24);

/// Chooses and places the labels of a view.
///
/// Candidates that are behind the camera or whose center is outside the view
/// are dropped, and so are those whose sphere is under [minSphereDiameter]
/// pixels across (the selected one is always kept). The selected node comes
/// first, then the nearest ones, up to [maxLabels]. Each label is centered on
/// its sphere, kept inside the view, and skipped when it would overlap a
/// label already placed (nearer ones win).
List<PlacedLabel> layoutLabels({
  required ViewCamera camera,
  required Iterable<LabelCandidate> candidates,
  String? selectedId,
  int maxLabels = 25,
  double minSphereDiameter = 12,
  Size Function(String text) measure = estimateLabelSize,
}) {
  final view = Offset.zero & camera.size;
  final visible = <({LabelCandidate candidate, Offset at, double distance})>[];
  for (final candidate in candidates) {
    final at = camera.project(candidate.center);
    if (at == null || !view.contains(at)) continue;
    final selected = candidate.id == selectedId;
    final diameter =
        2 * camera.screenRadius(candidate.center, candidate.radius);
    if (!selected && diameter < minSphereDiameter) continue;
    visible.add((
      candidate: candidate,
      at: at,
      distance: candidate.center.distanceTo(camera.position),
    ));
  }
  visible.sort((a, b) {
    final aSelected = a.candidate.id == selectedId;
    final bSelected = b.candidate.id == selectedId;
    if (aSelected != bSelected) return aSelected ? -1 : 1;
    final byDistance = a.distance.compareTo(b.distance);
    return byDistance != 0
        ? byDistance
        : a.candidate.id.compareTo(b.candidate.id);
  });

  final placed = <PlacedLabel>[];
  for (final (:candidate, :at, distance: _) in visible.take(maxLabels)) {
    final size = measure(candidate.text);
    var rect = Rect.fromCenter(
      center: at,
      width: size.width,
      height: size.height,
    );
    // Keep the whole label in the view.
    rect = rect.shift(
      Offset(
        _inside(rect.left, rect.right, view.left, view.right),
        _inside(rect.top, rect.bottom, view.top, view.bottom),
      ),
    );
    if (placed.any((label) => label.rect.overlaps(rect))) continue;
    placed.add(
      PlacedLabel(
        id: candidate.id,
        text: candidate.text,
        rect: rect,
        selected: candidate.id == selectedId,
      ),
    );
  }
  return placed;
}

/// How much to shift a span `[low, high]` to fit inside `[min, max]` (zero
/// when it fits or is wider than the space).
double _inside(double low, double high, double min, double max) {
  if (high - low >= max - min) return 0;
  if (low < min) return min - low;
  if (high > max) return max - high;
  return 0;
}
