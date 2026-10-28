import 'package:code_editor/core/editor/formatting/editor_formatting_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatting preferences default to disabled', () {
    expect(
      const EditorFormattingPreferences(),
      const EditorFormattingPreferences(
        formatOnSave: false,
        formatOnType: false,
        formatOnPaste: false,
      ),
    );
  });

  test('loads and persists preferences through the configured store', () async {
    final store = InMemoryEditorFormattingPreferencesStore(
      initialPreferences: const EditorFormattingPreferences(
        formatOnPaste: true,
      ),
    );
    final controller = EditorFormattingPreferencesController(
      preferencesStore: store,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.update(
      controller.preferences.copyWith(formatOnSave: true),
    );

    expect(controller.preferences.formatOnSave, isTrue);
    expect(controller.preferences.formatOnPaste, isTrue);
    expect(await store.read(), controller.preferences);
  });
}
