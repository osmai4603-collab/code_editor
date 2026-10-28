import 'package:flutter/material.dart';
import '../buffer/terminal_cursor.dart';

class TerminalConfigService extends ChangeNotifier {
  String fontFamily;
  double fontSize;
  double lineHeight;
  double letterSpacing;
  CursorShape cursorShape;
  bool cursorBlinking;
  int scrollbackLines;
  bool copyOnSelection;
  bool enableBell;
  bool smoothScrolling;

  TerminalConfigService({
    this.fontFamily = 'JetBrains Mono',
    this.fontSize = 13,
    this.lineHeight = 1.2,
    this.letterSpacing = -0.2,
    this.cursorShape = CursorShape.block,
    this.cursorBlinking = true,
    this.scrollbackLines = 1000,
    this.copyOnSelection = false,
    this.enableBell = false,
    this.smoothScrolling = false,
  });

  Size measureCharSize(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'W',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: Directionality.of(context),
    )..layout();
    return Size(painter.width, painter.height * lineHeight);
  }
}
