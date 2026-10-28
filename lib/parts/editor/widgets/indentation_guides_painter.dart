import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/editor/indentation/editor_indentation_options.dart';

class IndentationGuidesPainter extends CustomPainter {
  final List<int> indentationColumns;
  final TextStyle textStyle;
  final EditorIndentationOptions options;
  final double verticalOffset;
  final Color color;

  const IndentationGuidesPainter({
    required this.indentationColumns,
    required this.textStyle,
    required this.options,
    required this.verticalOffset,
    required this.color,
  });

  List<int> guideColumnsForLine(String line) {
    final prefix = RegExp(r'^[ \t]*').stringMatch(line) ?? '';
    var columns = 0;
    for (final character in prefix.split('')) {
      columns = character == '\t'
          ? ((columns ~/ options.tabSize) + 1) * options.tabSize
          : columns + 1;
    }

    return [
      for (
        var column = options.indentSize;
        column < columns;
        column += options.indentSize
      )
        column,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final spacePainter = TextPainter(
      text: TextSpan(text: ' ', style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final spaceWidth = spacePainter.width;
    if (spaceWidth <= 0) return;

    final lineMetricsPainter = TextPainter(
      text: TextSpan(text: 'M', style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final lineHeight = lineMetricsPainter.preferredLineHeight;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final firstVisibleLine = (verticalOffset / lineHeight)
        .floor()
        .clamp(0, indentationColumns.length)
        .toInt();
    final lastVisibleLine = ((verticalOffset + size.height) / lineHeight)
        .ceil()
        .clamp(0, indentationColumns.length)
        .toInt();
    for (
      var lineIndex = firstVisibleLine;
      lineIndex < lastVisibleLine;
      lineIndex++
    ) {
      final top = lineIndex * lineHeight - verticalOffset;
      for (
        var column = options.indentSize;
        column < indentationColumns[lineIndex];
        column += options.indentSize
      ) {
        final x = column * spaceWidth;
        if (x > size.width) break;
        canvas.drawLine(Offset(x, top), Offset(x, top + lineHeight), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant IndentationGuidesPainter oldDelegate) =>
      !listEquals(indentationColumns, oldDelegate.indentationColumns) ||
      textStyle != oldDelegate.textStyle ||
      options != oldDelegate.options ||
      verticalOffset != oldDelegate.verticalOffset ||
      color != oldDelegate.color;
}
