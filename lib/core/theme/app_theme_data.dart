import 'package:flutter/material.dart';

import '../syntax/theme/editor_token_theme.dart';
import 'editor_theme.dart';

class AppThemeData {
  final String id;
  final String label;
  final Brightness brightness;
  final EditorThemeData editorTheme;
  final EditorTokenTheme tokenTheme;
  final ThemeData materialTheme;

  AppThemeData({
    required this.id,
    required this.label,
    this.brightness = Brightness.dark,
    required this.editorTheme,
    required this.tokenTheme,
  }) : materialTheme = _buildMaterialTheme(editorTheme, brightness);

  static final darkModern = AppThemeData(
    id: 'dark-modern',
    label: 'Dark Modern',
    editorTheme: EditorThemeData.darkModern,
    tokenTheme: EditorTokenTheme.dark(),
  );

  static final lightModern = AppThemeData(
    id: 'light-modern',
    label: 'Light Modern',
    brightness: Brightness.light,
    editorTheme: EditorThemeData.lightModern,
    tokenTheme: EditorTokenTheme.light(),
  );

  static final List<AppThemeData> all = List.unmodifiable([
    darkModern,
    lightModern,
  ]);

  static AppThemeData? fromId(String? id) {
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return null;
  }

  static ThemeData _buildMaterialTheme(
    EditorThemeData editorTheme,
    Brightness brightness,
  ) {
    final baseTheme = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();
    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: editorTheme.accentColor,
            surface: editorTheme.editorBackground,
          )
        : ColorScheme.light(
            primary: editorTheme.accentColor,
            surface: editorTheme.editorBackground,
          );
    return baseTheme.copyWith(
      primaryColor: editorTheme.accentColor,
      scaffoldBackgroundColor: editorTheme.editorBackground,
      canvasColor: editorTheme.sideBarBackground,
      dividerColor: editorTheme.sideBarBorder,
      colorScheme: colorScheme,
      iconTheme: IconThemeData(color: editorTheme.editorForeground),
      primaryIconTheme: IconThemeData(color: editorTheme.editorForeground),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: editorTheme.accentColor,
        selectionColor: editorTheme.editorSelection,
        selectionHandleColor: editorTheme.accentColor,
      ),
    );
  }
}
