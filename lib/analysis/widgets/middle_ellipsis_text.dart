import 'package:material_ui/material_ui.dart';

/// [text] cut with `…` until `fits` accepts it, keeping its start and, more
/// of, its end: in a path the file name matters most, so it stays whole when
/// it can. Returns [text] itself when it already fits, and just `…` when
/// nothing else does.
String ellipsizeMiddle(String text, bool Function(String candidate) fits) {
  if (fits(text)) return text;
  // The most characters kept (head + tail) that still fit: binary search,
  // since a longer cut is never narrower.
  var low = 0;
  var high = text.length - 1;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (fits(_cut(text, middle))) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return _cut(text, low);
}

String _cut(String text, int kept) {
  // Two fifths from the start, three fifths from the end.
  final head = kept * 2 ~/ 5;
  final tail = kept - head;
  return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
}

/// A single line of text that is cut in the middle (not at the end) when it
/// is too wide, for paths and file names.
class MiddleEllipsisText extends StatelessWidget {
  const new(this.text, {super.key, this.style});

  /// The text.
  final String text;

  /// Its style (the ambient one by default).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        bool fits(String candidate) {
          final painter = TextPainter(
            text: TextSpan(text: candidate, style: effective),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width <= constraints.maxWidth;
        }

        return Text(
          ellipsizeMiddle(text, fits),
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          semanticsLabel: text,
        );
      },
    );
  }
}
