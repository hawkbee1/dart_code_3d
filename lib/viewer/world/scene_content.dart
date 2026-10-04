import 'dart:math' as math;

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/theme/code_world_colors.dart';
import 'package:dart_code_3d/viewer/world/sphere_instance.dart';
import 'package:dart_code_3d/viewer/world/visibility.dart';
import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart';

/// The shell of an open container, drawn from inside.
class ShellInstance extends Equatable {
  /// Creates a shell.
  const new({required this.sphere, required this.opacity});

  /// The container's sphere (its color is the container's kind color).
  final SphereInstance sphere;

  /// Target opacity: a tinted dome in interior view, nearly transparent in
  /// window view.
  final double opacity;

  @override
  List<Object?> get props => [sphere, opacity];
}

/// The links drawn with one geometry: same kind, width bucket and dimness.
class LinkBatch extends Equatable {
  /// Creates a batch key.
  const new({required this.kind, required this.widthBucket, required this.dim});

  /// The link kind (its color).
  final LinkKind kind;

  /// 0 for single links, 1 for 2–4, 2 for 5 or more.
  final int widthBucket;

  /// Whether the links are uncertain or external.
  final bool dim;

  @override
  List<Object?> get props => [kind, widthBucket, dim];
}

/// The width bucket of a link merging [count] links.
int widthBucketOf(int count) => count >= 5 ? 2 : (count >= 2 ? 1 : 0);

/// Everything the renderer draws for a [VisibleWorld], grouped by material.
class SceneContent {
  /// Creates the content.
  const new({
    required this.solid,
    required this.ghosts,
    required this.packages,
    required this.shells,
    required this.links,
    required this.center,
    required this.medianRadius,
    required this.linkScale,
  });

  /// Opaque spheres: declarations and members.
  final List<SphereInstance> solid;

  /// Translucent spheres: ghost parents (superclasses from outside).
  final List<SphereInstance> ghosts;

  /// Metallic spheres: external packages.
  final List<SphereInstance> packages;

  /// Shells of the open containers, outermost first.
  final List<ShellInstance> shells;

  /// Link segments (start, end) by batch.
  final Map<LinkBatch, List<(Vector3, Vector3)>> links;

  /// The middle of what is drawn (the container's center inside one): links
  /// are as wide as they are far from the camera, measured to this point.
  final Vector3 center;

  /// The median radius of the spheres drawn (1 without any).
  final double medianRadius;

  /// The radius of the level the camera is in (the world's or the
  /// container's): links never get wider than a hundredth of it.
  final double linkScale;

  /// The number of spheres drawn (shells excluded).
  int get sphereCount => solid.length + ghosts.length + packages.length;

  /// The number of link segments drawn.
  int get linkCount => links.values.fold(0, (sum, l) => sum + l.length);

  /// The world width of single links seen from [distance] away: about two
  /// pixels wide on screen at that distance, but never thinner than 3% of
  /// the typical sphere (so they stay visible among spheres) nor wider than
  /// 1% of the level.
  double linkWidthFor(double distance) {
    final floor = 0.03 * medianRadius;
    final ceiling = math.max(floor, 0.01 * linkScale);
    return (0.002 * distance).clamp(floor, ceiling);
  }

  /// The world width of the links in [bucket] seen from [distance] away.
  double widthOf(int bucket, double distance) =>
      linkWidthFor(distance) * const [1.0, 1.8, 2.6][bucket];
}

/// Opacity of the current container's shell in interior view.
const double interiorShellOpacity = 0.25;

/// Opacity of open containers' shells in window view.
const double windowShellOpacity = 0.08;

/// The content drawn for [visible] in [map] laid out at [positions].
///
/// [scale] is the radius of the level the camera is in (the current
/// container's, or the world's): it bounds the width of links.
SceneContent buildSceneContent({
  required CodeMap map,
  required Map<String, Vector3> positions,
  required CodeWorldColors colors,
  required VisibleWorld visible,
  required ViewMode mode,
  required double scale,
}) {
  SphereInstance sphere(String id) {
    final node = map.graph.nodes[id]!;
    return SphereInstance(
      nodeId: id,
      center: positions[id]!,
      radius: map.placements[id]!.radius,
      color: linearColor(colors.nodes[node.kind]!),
    );
  }

  final solid = <SphereInstance>[];
  final ghosts = <SphereInstance>[];
  final packages = <SphereInstance>[];
  for (final id in visible.visibleSpheres) {
    (switch (map.graph.nodes[id]!.kind) {
      CodeNodeKind.ghostParent => ghosts,
      CodeNodeKind.externalPackage => packages,
      CodeNodeKind.classDecl ||
      CodeNodeKind.mixinDecl ||
      CodeNodeKind.enumDecl ||
      CodeNodeKind.extensionDecl ||
      CodeNodeKind.extensionTypeDecl ||
      CodeNodeKind.method ||
      CodeNodeKind.constructor ||
      CodeNodeKind.getter ||
      CodeNodeKind.setter ||
      CodeNodeKind.function => solid,
    }).add(sphere(id));
  }
  final open = visible.openContainers;
  final shells = [
    for (final (i, id) in open.indexed)
      if (mode == ViewMode.window || i == open.length - 1)
        ShellInstance(
          sphere: sphere(id),
          opacity: mode == ViewMode.interior
              ? interiorShellOpacity
              : windowShellOpacity,
        ),
  ];
  final links = <LinkBatch, List<(Vector3, Vector3)>>{};
  for (final link in visible.links) {
    final batch = LinkBatch(
      kind: link.kind,
      widthBucket: widthBucketOf(link.count),
      dim: link.dim,
    );
    (links[batch] ??= []).add(
      linkSegment(
        positions[link.fromId]!,
        map.placements[link.fromId]!.radius,
        positions[link.toId]!,
        map.placements[link.toId]!.radius,
      ),
    );
  }
  final radii = [
    for (final id in visible.visibleSpheres) map.placements[id]!.radius,
  ]..sort();
  final container = open.lastOrNull;
  final center = Vector3.zero();
  if (container != null) {
    center.setFrom(positions[container]!);
  } else if (visible.visibleSpheres.isNotEmpty) {
    for (final id in visible.visibleSpheres) {
      center.add(positions[id]!);
    }
    center.scale(1 / visible.visibleSpheres.length);
  }
  return SceneContent(
    solid: solid,
    ghosts: ghosts,
    packages: packages,
    shells: shells,
    links: links,
    center: center,
    medianRadius: radii.isEmpty ? 1 : radii[radii.length ~/ 2],
    linkScale: scale,
  );
}

/// The segment drawn between spheres at [a] and [b] (radii [ra] and [rb]):
/// from surface to surface, so a link never starts inside a sphere. Spheres
/// that touch or overlap are joined center to center.
(Vector3, Vector3) linkSegment(Vector3 a, double ra, Vector3 b, double rb) {
  final offset = b - a;
  final distance = offset.length;
  if (distance <= ra + rb) return (a, b);
  final direction = offset.scaled(1 / distance);
  return (a + direction * ra, b - direction * rb);
}

/// The opacity of a shell [elapsed] seconds after it appeared: fades in
/// over [duration] up to [target], or appears at once when not [animate].
double shellOpacity(
  double elapsed,
  double target, {
  required bool animate,
  double duration = 0.2,
}) => animate ? target * (elapsed / duration).clamp(0.0, 1.0) : target;
