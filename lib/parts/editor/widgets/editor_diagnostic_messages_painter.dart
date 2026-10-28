import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/lsp/diagnostics/diagnostic_range_utils.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';

@immutable
class EditorDiagnosticMessage {
  final int line;
  final String message;
  final DiagnosticSeverity severity;

  const EditorDiagnosticMessage({
    required this.line,
    required this.message,
    required this.severity,
  });

  @override
  bool operator ==(Object other) =>
      other is EditorDiagnosticMessage &&
      line == other.line &&
      message == other.message &&
      severity == other.severity;

  @override
  int get hashCode => Object.hash(line, message, severity);
}

class EditorDiagnosticMessagesPainter extends CustomPainter {
  static const double messageGap = 50;
  static const double maxMessageWidth = 480;

  final List<String> lines;
  final List<EditorDiagnosticMessage> messages;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final EditorThemeData theme;
  final double lineHeight;
  final double verticalOffset;

  const EditorDiagnosticMessagesPainter({
    required this.lines,
    required this.messages,
    required this.textStyle,
    required this.textDirection,
    required this.theme,
    required this.lineHeight,
    required this.verticalOffset,
  });

  static List<EditorDiagnosticMessage> messagesForDiagnostics(
    List<DiagnosticItem> diagnostics,
    int lineCount,
  ) {
    final grouped = <int, List<DiagnosticItem>>{};
    for (final diagnostic in diagnostics) {
      final line = diagnostic.range.start.line;
      if (line < 0 || line >= lineCount || diagnostic.message.trim().isEmpty) {
        continue;
      }
      grouped.putIfAbsent(line, () => []).add(diagnostic);
    }

    return List.unmodifiable([
      for (final entry in grouped.entries)
        EditorDiagnosticMessage(
          line: entry.key,
          message: entry.value
              .map((diagnostic) => diagnostic.message.trim())
              .toSet()
              .join(' • '),
          severity: entry.value.reduce(
            (highest, diagnostic) =>
                DiagnosticRangeUtils.severityRank(diagnostic.severity) >
                    DiagnosticRangeUtils.severityRank(highest.severity)
                ? diagnostic
                : highest,
          ).severity,
        ),
    ]);
  }

  static double requiredWidth({
    required List<EditorDiagnosticMessage> messages,
    required TextStyle textStyle,
    required TextDirection textDirection,
  }) {
    var requiredWidth = 0.0;
    for (final message in messages) {
      final painter = TextPainter(
        text: TextSpan(text: message.message, style: textStyle),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxMessageWidth);
      requiredWidth = requiredWidth > painter.width
          ? requiredWidth
          : painter.width;
    }
    return requiredWidth == 0 ? 0 : requiredWidth + messageGap;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || lineHeight <= 0) return;
    final messagesByLine = {for (final message in messages) message.line: message};
    final firstVisibleLine = (verticalOffset / lineHeight)
        .floor()
        .clamp(0, lines.length)
        .toInt();
    final lastVisibleLine = ((verticalOffset + size.height) / lineHeight)
        .ceil()
        .clamp(0, lines.length)
        .toInt();

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (
      var lineIndex = firstVisibleLine;
      lineIndex < lastVisibleLine;
      lineIndex++
    ) {
      final message = messagesByLine[lineIndex];
      if (message == null) continue;

      final codePainter = TextPainter(
        text: TextSpan(text: lines[lineIndex], style: textStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      final messagePainter = TextPainter(
        text: TextSpan(
          text: message.message,
          style: textStyle.copyWith(
            color: theme.diagnosticColor(message.severity),
            fontSize: (textStyle.fontSize ?? 14) * 0.9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxMessageWidth);

      final top =
          lineIndex * lineHeight -
          verticalOffset +
          (lineHeight - messagePainter.height) / 2;
      messagePainter.paint(
        canvas,
        Offset(codePainter.width + messageGap, top),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EditorDiagnosticMessagesPainter oldDelegate) =>
      !listEquals(lines, oldDelegate.lines) ||
      !listEquals(messages, oldDelegate.messages) ||
      textStyle != oldDelegate.textStyle ||
      textDirection != oldDelegate.textDirection ||
      theme != oldDelegate.theme ||
      lineHeight != oldDelegate.lineHeight ||
      verticalOffset != oldDelegate.verticalOffset;
}
