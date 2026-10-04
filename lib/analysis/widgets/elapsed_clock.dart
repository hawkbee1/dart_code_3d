import 'dart:async';

import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `m:ss` (or `h:mm:ss` from an hour) for [seconds].
String formatElapsed(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}

/// The time since it appeared, counted every second.
class ElapsedClock extends StatefulWidget {
  const new({super.key});

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  late final Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _seconds++),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    context.l10n.analysisElapsed(formatElapsed(_seconds)),
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  );
}
