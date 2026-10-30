import 'package:code_editor/core/languages/definitions/built_in_languages.dart';
import 'package:code_editor/core/languages/models/language_definition.dart';
import 'package:code_editor/core/languages/registry/language_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguageRegistry', () {
    test('resolves built-in extensions and special filenames', () {
      final registry = createBuiltInLanguageRegistry();

      expect(registry.resolveLanguageId('/workspace/main.DART'), 'dart');
      expect(registry.resolveLanguageId('pubspec.yaml'), 'yaml');
      expect(registry.resolveLanguageId('README.md'), 'markdown');
      expect(registry.resolveLanguageId('unknown.file'), 'plaintext');
    });

    test('supports registering and replacing language definitions', () {
      final registry = LanguageRegistry([
        LanguageDefinition(
          id: 'custom',
          name: 'Custom',
          extensions: const ['.one'],
        ),
      ]);
      registry.register(
        LanguageDefinition(
          id: 'custom',
          name: 'Updated Custom',
          extensions: const ['.two'],
        ),
      );

      expect(registry.forPath('file.one'), isNull);
      expect(registry.forPath('file.two')?.name, 'Updated Custom');
    });
  });
}
