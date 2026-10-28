import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/syntax/theme/editor_token_theme.dart';
import 'package:code_editor/core/syntax/theme/token_color_palette.dart';
import 'package:code_editor/parts/editor/controllers/code_editor_controller.dart';

void main() {
  test('updating the token theme preserves text and selection', () {
    final controller = CodeEditorController(
      text: 'void main() {}',
      filePath: 'main.dart',
    );
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 5);
    var notifications = 0;
    controller.addListener(() => notifications++);

    final updatedTheme = EditorTokenTheme(
      palette: TokenColorPalette([Colors.white, Colors.white, Colors.red]),
    );
    controller.updateTheme(updatedTheme);

    expect(controller.theme, same(updatedTheme));
    expect(controller.text, 'void main() {}');
    expect(controller.selection, const TextSelection.collapsed(offset: 5));
    expect(
      controller.theme.getStyle(StandardColorId.keyword, 0).color,
      Colors.red,
    );
    expect(notifications, 1);
  });

  test('updating with the active token theme is a no-op', () {
    final theme = EditorTokenTheme.dark();
    final controller = CodeEditorController(
      text: 'main()',
      filePath: 'main.dart',
      theme: theme,
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.updateTheme(theme);

    expect(notifications, 0);
  });
}
