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

  test('round trips formatter selection and language-specific overrides', () {
    const preferences = EditorFormattingPreferences(
      formatOnSave: true,
      formatOnSaveMode: FormatOnSaveMode.modificationsIfAvailable,
      defaultFormatter: 'global-formatter',
      languageOverrides: {
        'dart': EditorFormattingOverride(
          formatOnType: true,
          defaultFormatter: 'dart-formatter',
        ),
      },
    );

    final restored = EditorFormattingPreferences.fromJson(
      preferences.toJson(),
    );

    expect(restored, preferences);
    expect(restored.forLanguage('dart').formatOnSave, isTrue);
    expect(restored.forLanguage('dart').formatOnType, isTrue);
    expect(restored.forLanguage('dart').defaultFormatter, 'dart-formatter');
    expect(restored.forLanguage('python').defaultFormatter, 'global-formatter');
  });

  test('reads legacy preferences using the new file-mode default', () {
    final preferences = EditorFormattingPreferences.fromJson({
      'formatOnSave': true,
      'formatOnType': false,
      'formatOnPaste': false,
    });

    expect(preferences.formatOnSave, isTrue);
    expect(preferences.formatOnSaveMode, FormatOnSaveMode.file);
    expect(preferences.languageOverrides, isEmpty);
  });
}
