import 'package:flutter/material.dart';
import '../../../../core/terminal/buffer/terminal_line.dart';
import '../../../../core/terminal/buffer/terminal_cursor.dart';
import '../../../../core/terminal/models/terminal_color_palette.dart';
import '../../../../core/terminal/models/terminal_state.dart';
import '../../../../core/terminal/models/terminal_style.dart';
import '../../../../core/terminal/services/terminal_config_service.dart';
import 'terminal_selection.dart';

class TerminalRenderer extends CustomPainter {
  final TerminalState state;
  final TerminalConfigService config;
  final TerminalColorPalette palette;
  final Size charSize;
  final int scrollOffset;
  final TerminalSelection? selection;

  TerminalRenderer({
    required this.state,
    required this.config,
    required this.palette,
    required this.charSize,
    this.scrollOffset = 0,
    this.selection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    if (charSize.width <= 0 || charSize.height <= 0) return;
    for (var row = 0; row < state.buffer.rows; row++) {
      final line = _lineForDisplay(row);
      for (var col = 0; col < state.buffer.cols; col++) {
        final cell = line.cells[col];
        final x = col * charSize.width;
        final y = row * charSize.height;
        final selected = selection?.contains(row, col) ?? false;
        final foreground = _foreground(cell.style);
        final background = _background(cell.style);
        if (selected || background != palette.background) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              y,
              charSize.width * (cell.width > 1 ? cell.width : 1),
              charSize.height,
            ),
            Paint()
              ..color = selected ? palette.selectionBackground : background,
          );
        }
        if (cell.character.isNotEmpty &&
            cell.character != ' ' &&
            !cell.style.hidden) {
          _paintText(
            canvas,
            cell.character,
            Offset(x, y),
            _textStyle(cell.style, foreground),
          );
        }
      }
    }
    _drawCursor(canvas, size);
  }

  TerminalLine _lineForDisplay(int row) {
    return state.buffer.lineAt(row, scrollOffset: scrollOffset);
  }

  Color _foreground(TerminalStyle style) {
    var color = palette.resolve(style.foregroundIndex);
    if (style.inverse) color = _background(style);
    if (style.dim) color = color.withValues(alpha: 0.5);
    return color;
  }

  Color _background(TerminalStyle style) {
    if (style.inverse) return palette.resolve(style.foregroundIndex);
    return style.backgroundIndex < 0
        ? palette.background
        : palette.resolve(style.backgroundIndex);
  }

  TextStyle _textStyle(TerminalStyle style, Color foreground) => TextStyle(
    fontFamily: config.fontFamily,
    fontSize: config.fontSize,
    color: foreground,
    fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
    decoration: TextDecoration.combine([
      if (style.underline) TextDecoration.underline,
      if (style.strikethrough) TextDecoration.lineThrough,
    ]),
    letterSpacing: config.letterSpacing,
  );

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawCursor(Canvas canvas, Size size) {
    final cursor = state.cursor;
    if (!cursor.visible ||
        scrollOffset != 0 ||
        cursor.row < 0 ||
        cursor.row >= state.buffer.rows ||
        cursor.col < 0 ||
        cursor.col >= state.buffer.cols) {
      return;
    }
    final rect = Rect.fromLTWH(
      cursor.col * charSize.width,
      cursor.row * charSize.height,
      charSize.width,
      charSize.height,
    ).intersect(Offset.zero & size);
    final paint = Paint()..color = palette.cursor;
    switch (config.cursorShape) {
      case CursorShape.block:
        canvas.drawRect(
          rect,
          paint..color = palette.cursor.withValues(alpha: 0.65),
        );
      case CursorShape.underline:
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2),
          paint,
        );
      case CursorShape.bar:
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, 2, rect.height),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant TerminalRenderer oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.config != config ||
      oldDelegate.palette != palette ||
      oldDelegate.charSize != charSize ||
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.selection != selection ||
      oldDelegate.state.buffer.lines != state.buffer.lines;
}
