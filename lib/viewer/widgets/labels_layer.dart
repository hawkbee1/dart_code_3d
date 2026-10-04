import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/viewer/navigation/fly_navigator.dart';
import 'package:dart_code_3d/viewer/world/code_world.dart';
import 'package:dart_code_3d/viewer/world/label_layout.dart';
import 'package:material_ui/material_ui.dart';

/// The names of the nearest spheres, drawn over the 3D area as Flutter text
/// (not 3D text): the selected sphere and up to [maxLabels] others, those in
/// front of the camera and big enough on screen, without overlaps.
///
/// It follows the camera: it redraws whenever [navigator] notifies.
class LabelsLayer extends StatefulWidget {
  const new({
    required this.navigator,
    required this.world,
    super.key,
    this.maxLabels = 25,
  });

  /// The camera the labels are projected through.
  final FlyNavigator navigator;

  /// What is drawn (and which sphere is highlighted).
  final CodeWorld world;

  /// The most labels shown at once.
  final int maxLabels;

  @override
  State<LabelsLayer> createState() => _LabelsLayerState();
}

class _LabelsLayerState extends State<LabelsLayer> {
  final _sizes = <String, Size>{};
  TextStyle? _measuredStyle;
  TextScaler? _measuredScaler;

  Size _measure(String text, TextStyle style, TextScaler scaler) {
    if (_measuredStyle != style || _measuredScaler != scaler) {
      _sizes.clear();
      _measuredStyle = style;
      _measuredScaler = scaler;
    }
    return _sizes[text] ??= () {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout(maxWidth: 220);
      final size = painter.size;
      painter.dispose();
      return Size(
        size.width + _padding.horizontal + 2,
        size.height + _padding.vertical + 2,
      );
    }();
  }

  static const _padding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall!;
    final scaler = MediaQuery.textScalerOf(context);
    final colors = context.worldColors;
    final world = widget.world;
    final graph = world.map.graph;
    final candidates = [
      for (final sphere in [
        ...world.content.solid,
        ...world.content.ghosts,
        ...world.content.packages,
      ])
        (
          id: sphere.nodeId,
          text: graph.nodes[sphere.nodeId]!.name,
          center: sphere.center,
          radius: sphere.radius,
        ),
    ];
    final selectedId = world.highlighted?.nodeId;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => ListenableBuilder(
          listenable: widget.navigator,
          builder: (context, _) {
            final labels = layoutLabels(
              camera: widget.navigator.viewCamera(constraints.biggest),
              candidates: candidates,
              selectedId: selectedId,
              maxLabels: widget.maxLabels,
              measure: (text) => _measure(text, style, scaler),
            );
            return Stack(
              children: [
                for (final label in labels)
                  Positioned.fromRect(
                    rect: label.rect,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: label.selected
                            ? Border.all(color: colors.selection, width: 2)
                            : null,
                      ),
                      child: Padding(
                        padding: _padding,
                        child: Text(
                          label.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A small cross in the middle of the 3D area: what `Enter` selects.
class Crosshair extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: CustomPaint(
        size: const Size.square(24),
        painter: _CrosshairPainter(
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    ),
  );
}

class _CrosshairPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    const gap = 4.0;
    final reach = size.width / 2;
    canvas
      ..drawLine(Offset(c.dx - reach, c.dy), Offset(c.dx - gap, c.dy), paint)
      ..drawLine(Offset(c.dx + gap, c.dy), Offset(c.dx + reach, c.dy), paint)
      ..drawLine(Offset(c.dx, c.dy - reach), Offset(c.dx, c.dy - gap), paint)
      ..drawLine(Offset(c.dx, c.dy + gap), Offset(c.dx, c.dy + reach), paint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter oldDelegate) =>
      oldDelegate.color != color;
}
