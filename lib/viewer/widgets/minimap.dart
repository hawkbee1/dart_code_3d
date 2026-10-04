import 'dart:math' as math;

import 'package:code_graph/code_graph.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/navigation/world_controller.dart';
import 'package:dart_code_3d/viewer/world/minimap_geometry.dart';
import 'package:dart_code_3d/viewer/world/world_transforms.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// A top-down map of what is inside the current container (the top level at
/// the world): a circle per sphere in its kind color, the camera and where it
/// looks, and the selected sphere ringed. Tapping a sphere selects it and
/// flies there ([onSelect]); the header collapses it.
class Minimap extends StatefulWidget {
  const new({
    required this.map,
    required this.containerId,
    required this.controller,
    required this.onSelect,
    super.key,
    this.selectedId,
    this.initiallyExpanded = true,
    this.side = 176,
  });

  /// The code map.
  final CodeMap map;

  /// The container the camera is in (the world when null): its children are
  /// drawn.
  final String? containerId;

  /// Where the camera is, and a notification whenever it moves.
  final WorldController controller;

  /// Called with the sphere tapped.
  final ValueChanged<String> onSelect;

  /// The selected node, ringed on the map (its sphere, or the sphere it is
  /// inside).
  final String? selectedId;

  /// Whether it starts expanded.
  final bool initiallyExpanded;

  /// The side of the square map, in logical pixels.
  final double side;

  @override
  State<Minimap> createState() => _MinimapState();
}

class _MinimapState extends State<Minimap> {
  late bool _expanded = widget.initiallyExpanded;

  List<MinimapSphere> get _spheres {
    final positions = cachedWorldPositions(widget.map);
    return [
      for (final node in widget.map.graph.childrenOf(widget.containerId))
        (
          id: node.id,
          center: positions[node.id]!,
          radius: widget.map.placements[node.id]!.radius,
        ),
    ];
  }

  /// What the map is fitted to: the packages sit far from the code and would
  /// shrink it to a speck, so they are pinned to the edge instead (unless they
  /// are all there is).
  List<MinimapSphere> _fitted(List<MinimapSphere> spheres) {
    final code = [
      for (final s in spheres)
        if (widget.map.graph.nodes[s.id]!.kind != CodeNodeKind.externalPackage)
          s,
    ];
    return code.isEmpty ? spheres : code;
  }

  /// The drawn sphere that stands for the selection: itself or its nearest
  /// ancestor on the map.
  String? _selectedSphere(List<MinimapSphere> spheres) {
    final selected = widget.selectedId;
    if (selected == null) return null;
    final onMap = {for (final s in spheres) s.id};
    var id = selected;
    while (true) {
      if (onMap.contains(id)) return id;
      final parent = widget.map.graph.nodes[id]?.parentId;
      if (parent == null) return null;
      id = parent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final spheres = _spheres;
    final projection = MinimapProjection.fit(
      _fitted(spheres),
      Size.square(widget.side),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(spacing.sm),
      ),
      child: SizedBox(
        width: widget.side,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Text(
                      l10n.minimapTitle,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded
                        ? l10n.minimapCollapse
                        : l10n.minimapExpand,
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
            if (_expanded)
              Semantics(
                label: l10n.minimapSemantics(spheres.length),
                child: GestureDetector(
                  onTapUp: (details) {
                    final hit = minimapHit(
                      details.localPosition,
                      spheres,
                      projection,
                    );
                    if (hit != null) widget.onSelect(hit);
                  },
                  child: CustomPaint(
                    size: Size.square(widget.side),
                    painter: _MinimapPainter(
                      spheres: spheres,
                      projection: projection,
                      controller: widget.controller,
                      nodeColors: context.worldColors.nodes,
                      kinds: {
                        for (final s in spheres)
                          s.id: widget.map.graph.nodes[s.id]!.kind,
                      },
                      selectedId: _selectedSphere(spheres),
                      selectionColor: context.worldColors.selection,
                      cameraColor: theme.colorScheme.primary,
                      outlineColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  new({
    required this.spheres,
    required this.projection,
    required this.controller,
    required this.nodeColors,
    required this.kinds,
    required this.selectedId,
    required this.selectionColor,
    required this.cameraColor,
    required this.outlineColor,
  }) : super(repaint: controller);

  final List<MinimapSphere> spheres;
  final MinimapProjection projection;
  final WorldController controller;
  final Map<CodeNodeKind, Color> nodeColors;
  final Map<String, CodeNodeKind> kinds;
  final String? selectedId;
  final Color selectionColor;
  final Color cameraColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // Higher spheres on top of lower ones.
    final byHeight = [...spheres]
      ..sort((a, b) => a.center.y.compareTo(b.center.y));
    for (final sphere in byHeight) {
      final id = sphere.id;
      final (:at, radius: r) = projection.place(sphere);
      canvas
        ..drawCircle(
          at,
          r,
          Paint()..color = nodeColors[kinds[id]]!.withValues(alpha: 0.8),
        )
        ..drawCircle(
          at,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = outlineColor,
        );
      if (id == selectedId) {
        canvas.drawCircle(
          at,
          r + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = selectionColor,
        );
      }
    }
    _paintCamera(canvas);
  }

  void _paintCamera(Canvas canvas) {
    final navigator = controller.navigator;
    if (navigator == null) return;
    final at = projection.toMapClamped(navigator.position);
    final forward = navigator.forward;
    // Straight up or down: no direction on the map.
    final heading = math.sqrt(forward.x * forward.x + forward.z * forward.z);
    final direction = heading < 1e-6
        ? const Offset(0, -1)
        : Offset(forward.x / heading, forward.z / heading);
    final side = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(at.dx + direction.dx * 9, at.dy + direction.dy * 9)
      ..lineTo(
        at.dx - direction.dx * 5 + side.dx * 5,
        at.dy - direction.dy * 5 + side.dy * 5,
      )
      ..lineTo(
        at.dx - direction.dx * 5 - side.dx * 5,
        at.dy - direction.dy * 5 - side.dy * 5,
      )
      ..close();
    canvas
      ..drawPath(path, Paint()..color = cameraColor)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.9),
      );
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) =>
      !listEquals(oldDelegate.spheres, spheres) ||
      oldDelegate.projection.scale != projection.scale ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.nodeColors != nodeColors ||
      oldDelegate.cameraColor != cameraColor;
}
