import 'package:code_editor/core/editor/formatting/text_edit_applier.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const applier = TextEditApplier();

  test('applies non-overlapping edits once and adjusts the selection', () {
    const current = TextEditingValue(
      text: 'a\nb\nc',
      selection: TextSelection.collapsed(offset: 4),
    );
    final result = applier.apply(current, const [
      TextEdit(
        range: LspRange(
          start: LspPosition(line: 0, character: 0),
          end: LspPosition(line: 0, character: 1),
        ),
        newText: 'alpha',
      ),
      TextEdit(
        range: LspRange(
          start: LspPosition(line: 2, character: 0),
          end: LspPosition(line: 2, character: 1),
        ),
        newText: 'charlie',
      ),
    ]);

    expect(result.text, 'alpha\nb\ncharlie');
    expect(result.selection.extentOffset, 8);
  });

  test('rejects invalid and overlapping edits without producing text', () {
    const current = TextEditingValue(
      text: 'abc',
      selection: TextSelection.collapsed(offset: 1),
    );
    expect(
      () => applier.apply(current, const [
        TextEdit(
          range: LspRange(
            start: LspPosition(line: 0, character: 0),
            end: LspPosition(line: 0, character: 2),
          ),
          newText: 'x',
        ),
        TextEdit(
          range: LspRange(
            start: LspPosition(line: 0, character: 1),
            end: LspPosition(line: 0, character: 3),
          ),
          newText: 'y',
        ),
      ]),
      throwsFormatException,
    );
    expect(
      () => applier.apply(current, const [
        TextEdit(
          range: LspRange(
            start: LspPosition(line: 1, character: 0),
            end: LspPosition(line: 1, character: 1),
          ),
          newText: 'x',
        ),
      ]),
      throwsFormatException,
    );
  });
}
