import 'dart:ui' show FramePhase, FrameTiming, TimingsCallback;

import 'package:dart_code_3d/app/app.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Frame statistics for development builds: frames per second, average
/// build (UI thread) and raster times, and the number of spheres and links
/// drawn.
///
/// The numbers come from Flutter's frame timings, so they are meaningful
/// in profile builds only. Developer-facing: the texts are not localized.
class DebugOverlay extends StatefulWidget {
  const new({
    required this.instanceCount,
    required this.linkCount,
    super.key,
    this.addTimingsCallback,
    this.removeTimingsCallback,
  });

  /// The number of spheres drawn.
  final int instanceCount;

  /// The number of links drawn.
  final int linkCount;

  /// Registers for frame timings (`SchedulerBinding` by default).
  final void Function(TimingsCallback callback)? addTimingsCallback;

  /// Unregisters from frame timings (`SchedulerBinding` by default).
  final void Function(TimingsCallback callback)? removeTimingsCallback;

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  static const _window = 120;
  final _timings = <FrameTiming>[];

  @override
  void initState() {
    super.initState();
    (widget.addTimingsCallback ?? SchedulerBinding.instance.addTimingsCallback)(
      _onTimings,
    );
  }

  @override
  void dispose() {
    (widget.removeTimingsCallback ??
        SchedulerBinding.instance.removeTimingsCallback)(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    setState(() {
      _timings.addAll(timings);
      if (_timings.length > _window) {
        _timings.removeRange(0, _timings.length - _window);
      }
    });
  }

  String get _summary {
    // Frames per second between the first and the last vsync.
    if (_timings.length < 2) return 'waiting for frames…';
    final first = _timings.first.timestampInMicroseconds(FramePhase.vsyncStart);
    final last = _timings.last.timestampInMicroseconds(FramePhase.vsyncStart);
    final seconds = (last - first) / Duration.microsecondsPerSecond;
    final fps = seconds <= 0 ? 0 : (_timings.length - 1) / seconds;
    double averageMs(Duration Function(FrameTiming t) of) =>
        _timings.map((t) => of(t).inMicroseconds).reduce((a, b) => a + b) /
        _timings.length /
        1000;
    return '${fps.toStringAsFixed(0)} fps\n'
        'build ${averageMs((t) => t.buildDuration).toStringAsFixed(1)} ms\n'
        'raster ${averageMs((t) => t.rasterDuration).toStringAsFixed(1)} ms';
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(spacing.xs),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: Text(
              '$_summary\n'
              '${widget.instanceCount} spheres · ${widget.linkCount} links',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
