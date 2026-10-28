import 'package:code_editor/core/editor/indentation/editor_indentation_options.dart';
import 'package:code_editor/core/editor/indentation/editor_input_formatter.dart';
import 'package:code_editor/core/editor/indentation/indentation_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = IndentationService();

  group('IndentationService', () {
    test('detects space indentation size and ignores blank lines', () {
      final options = service.detect('root\n  child\n\n    nested');

      expect(options.insertSpaces, isTrue);
      expect(options.indentSize, 2);
      expect(options.tabSize, 2);
    });

    test('detects tabs and respects disabled detection', () {
      expect(service.detect('root\n\tchild').insertSpaces, isFalse);
      const explicit = EditorIndentationOptions(
        tabSize: 8,
        indentSize: 2,
        insertSpaces: false,
        detectIndentation: false,
      );
      expect(service.detect('root\n  child', fallback: explicit), explicit);
    });

    test(
      'keeps the configured size when the file has only one indent level',
      () {
        const fallback = EditorIndentationOptions(tabSize: 8, indentSize: 2);
        expect(service.detect('root\n    child', fallback: fallback), fallback);
      },
    );

    test('prefers tabs when indentation mixes tabs and spaces', () {
      const fallback = EditorIndentationOptions(indentSize: 2);
      final detected = service.detect('root\n \tchild', fallback: fallback);

      expect(detected.insertSpaces, isFalse);
      expect(detected.indentSize, fallback.indentSize);
    });

    test('converts indentation without modifying line contents', () {
      const options = EditorIndentationOptions(tabSize: 4, indentSize: 2);
      expect(
        service.convertIndentation(
          '\tvalue\n  next\n',
          options,
          toSpaces: true,
        ),
        '    value\n  next\n',
      );
    });

    test('keeps tab width independent from the space indent size', () {
      const options = EditorIndentationOptions(tabSize: 8, indentSize: 2);
      expect(
        service.convertIndentation('  child', options, toSpaces: false),
        '  child',
      );
      expect(
        service.convertIndentation(
          '  child\n    nested',
          options,
          toSpaces: true,
          targetIndentSize: 4,
        ),
        '    child\n        nested',
      );
    });

    test('expands tabs to the next tab stop when preceded by spaces', () {
      const options = EditorIndentationOptions(tabSize: 4, indentSize: 2);

      expect(
        service.convertIndentation(' \tchild', options, toSpaces: true),
        '    child',
      );
    });
  });

  group('EditorInputFormatter', () {
    TextEditingValue type(
      String oldText,
      String newText, {
      int? cursor,
      String languageId = 'plaintext',
    }) {
      final oldValue = TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: cursor ?? oldText.length),
      );
      return EditorInputFormatter(
        options: const EditorIndentationOptions(indentSize: 2),
        languageId: languageId,
      ).formatEditUpdate(
        oldValue,
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('indents Enter after opening braces and between empty pairs', () {
      final normal = type('if (ready) {', 'if (ready) {\n');
      expect(normal.text, 'if (ready) {\n  ');

      final emptyPair = type('{}', '{\n}', cursor: 1);
      expect(emptyPair.text, '{\n  \n}');
      expect(emptyPair.selection.extentOffset, 4);

      final parenthesisPair = type('()', '(\n)', cursor: 1);
      expect(parenthesisPair.text, '(\n  \n)');
    });

    test('uses language-specific Python block indentation', () {
      final result = type('if ready:', 'if ready:\n', languageId: 'python');
      expect(result.text, 'if ready:\n  ');
    });

    test('inserts and skips closing brackets and wraps selected text', () {
      final pair = type('', '(');
      expect(pair.text, '()');
      expect(pair.selection.extentOffset, 1);

      final skip = type('()', '())', cursor: 1);
      expect(skip.text, '()');
      expect(skip.selection.extentOffset, 2);

      final quote = type('', '"');
      expect(quote.text, '""');
      final skippedQuote = type('""', '"""', cursor: 1);
      expect(skippedQuote.text, '""');
      expect(skippedQuote.selection.extentOffset, 2);

      final wrapped =
          EditorInputFormatter(
            options: const EditorIndentationOptions(),
            languageId: 'plaintext',
          ).formatEditUpdate(
            const TextEditingValue(
              text: 'word',
              selection: TextSelection(baseOffset: 0, extentOffset: 4),
            ),
            const TextEditingValue(
              text: '(word',
              selection: TextSelection.collapsed(offset: 1),
            ),
          );
      expect(wrapped.text, '(word)');
      expect(wrapped.selection.baseOffset, 1);
      expect(wrapped.selection.extentOffset, 5);
    });

    test('outdents when typing a closing brace on an indented blank line', () {
      final closing = type('{\n  ', '{\n  }');
      expect(closing.text, '{\n}');
    });

    test('does not outdent for an unmatched closing bracket', () {
      final closing = type('if ready:\n  ', 'if ready:\n  }');

      expect(closing.text, 'if ready:\n  }');
    });

    test('does not treat brackets in comments as matching pairs', () {
      final closing = type('# {\n  ', '# {\n  }', languageId: 'python');

      expect(closing.text, '# {\n  }');
    });

    test(
      'typing a command after Enter keeps the indentation already inserted',
      () {
        final result = type('if ready:\n  ', 'if ready:\n  run');

        expect(result.text, 'if ready:\n  run');
      },
    );

    test('reports typed trigger characters without reporting deletions', () {
      final typedCharacters = <String>[];
      final formatter = EditorInputFormatter(
        options: const EditorIndentationOptions(),
        languageId: 'plaintext',
        onCharacterTyped: typedCharacters.add,
      );
      const oldValue = TextEditingValue(
        text: 'value',
        selection: TextSelection.collapsed(offset: 5),
      );

      formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: 'value:',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: 'valu',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      expect(typedCharacters, [':']);
    });

    test(
      'Enter copies existing indentation without inventing file-start indent',
      () {
        final unindented = type('run()', 'run()\n');
        final indented = type('  run()', '  run()\n');

        expect(unindented.text, 'run()\n');
        expect(indented.text, '  run()\n  ');
      },
    );
  });
}
