import 'package:flutter/material.dart';

/// معرفات الألوان الثابتة في لوحة الثيم المعيارية
abstract final class StandardColorId {
  static const int none = 0;
  static const int defaultForeground = 1;
  static const int keyword = 2;
  static const int controlKeyword = 3;
  static const int stringLiteral = 4;
  static const int comment = 5;
  static const int number = 6;
  static const int type = 7;
  static const int function = 8;
  static const int variable = 9;
  static const int constant = 10;
  static const int operator = 11;
  static const int regex = 12;
  static const int escapeCharacter = 13;
  static const int preprocessor = 14;

  // ألوان الأقواس المتداخلة
  static const int bracketLevel1 = 15;
  static const int bracketLevel2 = 16;
  static const int bracketLevel3 = 17;
}

/// لوحة الألوان التي تربط كل معرف `ColorId` بكائن `Color`
class TokenColorPalette {
  final List<Color> _colors;

  TokenColorPalette(List<Color> colors) : _colors = List.unmodifiable(colors);

  /// لوحة الألوان الافتراضية المستوحاة من ثيم VS Code Dark+
  factory TokenColorPalette.dark() {
    final colors = List<Color>.filled(32, const Color(0xFFD4D4D4));
    colors[StandardColorId.none] = const Color(0xFFD4D4D4);
    colors[StandardColorId.defaultForeground] = const Color(0xFFD4D4D4);
    colors[StandardColorId.keyword] = const Color(0xFF569CD6); // Blue
    colors[StandardColorId.controlKeyword] = const Color(0xFFC586C0); // Magenta
    colors[StandardColorId.stringLiteral] = const Color(0xFFCE9178); // Orange-Brown
    colors[StandardColorId.comment] = const Color(0xFF6A9955); // Green
    colors[StandardColorId.number] = const Color(0xFFB5CEA8); // Light Green
    colors[StandardColorId.type] = const Color(0xFF4EC9B0); // Teal
    colors[StandardColorId.function] = const Color(0xFFDCDCAA); // Yellow
    colors[StandardColorId.variable] = const Color(0xFF9CDCFE); // Light Blue
    colors[StandardColorId.constant] = const Color(0xFF4FC1FF); // Cyan
    colors[StandardColorId.operator] = const Color(0xFFD4D4D4); // Light Gray
    colors[StandardColorId.regex] = const Color(0xFFD16969); // Reddish
    colors[StandardColorId.escapeCharacter] = const Color(0xFFD7BA7D); // Yellowish
    colors[StandardColorId.preprocessor] = const Color(0xFF808080); // Gray

    // ألوان الأقواس المتداخلة
    colors[StandardColorId.bracketLevel1] = const Color(0xFFFFD700); // Gold
    colors[StandardColorId.bracketLevel2] = const Color(0xFFDA70D6); // Orchid
    colors[StandardColorId.bracketLevel3] = const Color(0xFF179FFF); // Sky Blue

    return TokenColorPalette(colors);
  }

  factory TokenColorPalette.light() {
    final colors = List<Color>.filled(32, const Color(0xFF3B3B3B));
    colors[StandardColorId.none] = const Color(0xFF3B3B3B);
    colors[StandardColorId.defaultForeground] = const Color(0xFF3B3B3B);
    colors[StandardColorId.keyword] = const Color(0xFF0000FF);
    colors[StandardColorId.controlKeyword] = const Color(0xFFAF00DB);
    colors[StandardColorId.stringLiteral] = const Color(0xFFA31515);
    colors[StandardColorId.comment] = const Color(0xFF008000);
    colors[StandardColorId.number] = const Color(0xFF098658);
    colors[StandardColorId.type] = const Color(0xFF267F99);
    colors[StandardColorId.function] = const Color(0xFF795E26);
    colors[StandardColorId.variable] = const Color(0xFF001080);
    colors[StandardColorId.constant] = const Color(0xFF0070C1);
    colors[StandardColorId.operator] = const Color(0xFF3B3B3B);
    colors[StandardColorId.regex] = const Color(0xFF811F3F);
    colors[StandardColorId.escapeCharacter] = const Color(0xFFEE0000);
    colors[StandardColorId.preprocessor] = const Color(0xFF808080);
    colors[StandardColorId.bracketLevel1] = const Color(0xFF0431FA);
    colors[StandardColorId.bracketLevel2] = const Color(0xFF319331);
    colors[StandardColorId.bracketLevel3] = const Color(0xFF7B3814);

    return TokenColorPalette(colors);
  }

  /// استرجاع اللون بواسطة معرّفه
  Color getColor(int colorId) {
    if (colorId <= 0 || colorId >= _colors.length) {
      return _colors[StandardColorId.defaultForeground];
    }
    return _colors[colorId];
  }
}
