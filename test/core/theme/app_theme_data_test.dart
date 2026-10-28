import 'package:flutter_test/flutter_test.dart';
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
}
