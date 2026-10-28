import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/syntax/theme/token_color_palette.dart';
import 'package:code_editor/core/theme/app_theme_data.dart';

void main() {
  test('dark modern derives Material colors from the editor theme', () {
    final theme = AppThemeData.darkModern;

    expect(
      theme.materialTheme.scaffoldBackgroundColor,
      theme.editorTheme.editorBackground,
    );
    expect(
      theme.materialTheme.canvasColor,
      theme.editorTheme.sideBarBackground,
    );
    expect(theme.materialTheme.dividerColor, theme.editorTheme.sideBarBorder);
    expect(
      theme.materialTheme.colorScheme.primary,
      theme.editorTheme.accentColor,
    );
    expect(
      theme.materialTheme.colorScheme.surface,
      theme.editorTheme.editorBackground,
    );
  });

  test('light modern uses light Material colors and token colors', () {
    final theme = AppThemeData.lightModern;

    expect(theme.brightness, Brightness.light);
    expect(theme.materialTheme.brightness, Brightness.light);
    expect(
      theme.materialTheme.scaffoldBackgroundColor,
      theme.editorTheme.editorBackground,
    );
    expect(
      theme.materialTheme.colorScheme.primary,
      theme.editorTheme.accentColor,
    );
    expect(
      theme.tokenTheme.getStyle(StandardColorId.keyword, 0).color,
      const Color(0xFF0000FF),
    );
    expect(
      theme.tokenTheme.getStyle(StandardColorId.stringLiteral, 0).color,
      const Color(0xFFA31515),
    );
    expect(theme.editorTheme.terminalAnsiColors, hasLength(16));
  });

  test('themes can be restored by id and unknown ids are rejected', () {
    expect(AppThemeData.fromId('dark-modern'), same(AppThemeData.darkModern));
    expect(AppThemeData.fromId('light-modern'), same(AppThemeData.lightModern));
    expect(AppThemeData.fromId('removed-theme'), isNull);
  });

  test('light token palette has colors for all standard ids', () {
    final palette = TokenColorPalette.light();

    for (var id = StandardColorId.none; id <= StandardColorId.bracketLevel3; id++) {
      expect(palette.getColor(id), isNotNull);
    }
  });
}
