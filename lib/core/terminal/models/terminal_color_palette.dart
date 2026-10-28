import 'package:flutter/material.dart';

class TerminalColorPalette {
  static const List<Color> defaultAnsiColors = [
    Color(0xFF000000),
    Color(0xFFCD3131),
    Color(0xFF0DBC79),
    Color(0xFFE5E510),
    Color(0xFF2472C8),
    Color(0xFFBC3FBC),
    Color(0xFF11A8CD),
    Color(0xFFE5E5E5),
    Color(0xFF666666),
    Color(0xFFF14C4C),
    Color(0xFF23D18B),
    Color(0xFFF5F543),
    Color(0xFF3B8EEA),
    Color(0xFFD670D6),
    Color(0xFF29B8DB),
    Color(0xFFFFFFFF),
  ];

  final List<Color> ansiColors;
  final Color foreground;
  final Color background;
  final Color cursor;
  final Color selectionBackground;

  const TerminalColorPalette({
    this.ansiColors = defaultAnsiColors,
    this.foreground = const Color(0xFFD4D4D4),
    this.background = const Color(0xFF1E1E1E),
    this.cursor = const Color(0xFFAEAFAD),
    this.selectionBackground = const Color(0xFF264F78),
  });

  static final List<Color> cubeColors = List.unmodifiable(
    List.generate(216, (index) {
      const levels = [0, 95, 135, 175, 215, 255];
      final red = levels[index ~/ 36];
      final green = levels[(index ~/ 6) % 6];
      final blue = levels[index % 6];
      return Color.fromARGB(255, red, green, blue);
    }),
  );

  static final List<Color> grayscaleColors = List.unmodifiable(
    List.generate(
      24,
      (index) =>
          Color.fromARGB(255, 8 + index * 10, 8 + index * 10, 8 + index * 10),
    ),
  );

  Color resolve(int index) {
    if (index < 0) return foreground;
    if (index >= 0x1000000) return Color(0xFF000000 | (index & 0xFFFFFF));
    if (index < ansiColors.length) return ansiColors[index];
    if (index < 232) return cubeColors[index - 16];
    if (index < 256) return grayscaleColors[index - 232];
    return foreground;
  }

  static const dark = TerminalColorPalette();
}
