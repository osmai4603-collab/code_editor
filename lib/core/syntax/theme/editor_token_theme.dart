import 'package:flutter/material.dart';
import '../model/encoded_token_attributes.dart';
import 'token_color_palette.dart';

/// ثيم ألوان ورموز المحرر مع تخزين مؤقت للأنماط (Flyweight Style Cache)
class EditorTokenTheme {
  final TokenColorPalette palette;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;

  // ذاكرة تخزين مؤقتة للأنماط لتفادي استهلاك الذاكرة أثناء الرسم المتكرر
  // المفتاح: (colorId << 4) | (fontStyle & 0xF)
  final Map<int, TextStyle> _styleCache = {};

  EditorTokenTheme({
    required this.palette,
    this.fontFamily = 'JetBrains Mono',
    this.fontSize = 13.5,
    this.lineHeight = 1.48,
  });

  factory EditorTokenTheme.dark({
    String fontFamily = 'JetBrains Mono',
    double fontSize = 13.5,
    double lineHeight = 1.48,
  }) {
    return EditorTokenTheme(
      palette: TokenColorPalette.dark(),
      fontFamily: fontFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
    );
  }

  factory EditorTokenTheme.light({
    String fontFamily = 'JetBrains Mono',
    double fontSize = 13.5,
    double lineHeight = 1.48,
  }) {
    return EditorTokenTheme(
      palette: TokenColorPalette.light(),
      fontFamily: fontFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
    );
  }

  /// الحصول على كائن `TextStyle` مطابق لمعرف اللون وقناع نمط الخط
  TextStyle getStyle(int colorId, int fontStyle) {
    final key = (colorId << 4) | (fontStyle & 0x0F);
    final cached = _styleCache[key];
    if (cached != null) return cached;

    final color = palette.getColor(colorId);
    final isItalic = (fontStyle & FontStyleMask.italic) != 0;
    final isBold = (fontStyle & FontStyleMask.bold) != 0;
    final isUnderline = (fontStyle & FontStyleMask.underline) != 0;
    final isStrikethrough = (fontStyle & FontStyleMask.strikethrough) != 0;

    TextDecoration? decoration;
    if (isUnderline && isStrikethrough) {
      decoration = TextDecoration.combine([
        TextDecoration.underline,
        TextDecoration.lineThrough,
      ]);
    } else if (isUnderline) {
      decoration = TextDecoration.underline;
    } else if (isStrikethrough) {
      decoration = TextDecoration.lineThrough;
    }

    final style = TextStyle(
      color: color,
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      decoration: decoration,
    );

    _styleCache[key] = style;
    return style;
  }
}
