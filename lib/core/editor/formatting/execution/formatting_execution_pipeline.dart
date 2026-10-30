import 'package:flutter/services.dart';

import 'package:code_editor/core/lsp/protocol/lsp_types.dart';

import '../diff/formatting_diff_engine.dart';
import '../editor_text_change.dart';
import '../text_edit_applier.dart';

class FormattingExecutionPipeline {
  final FormattingDiffEngine diffEngine;
  final TextEditApplier textEditApplier;

  const FormattingExecutionPipeline({
    this.diffEngine = const FormattingDiffEngine(),
    this.textEditApplier = const TextEditApplier(),
  });

  Future<TextEditingValue> apply(
    TextEditingValue current,
    List<TextEdit> edits,
  ) async {
    final candidate = textEditApplier.apply(current, edits);
    final changes = await diffEngine.compute(current.text, candidate.text);
    if (changes.isEmpty) return current;
    final minimalEdits = changes
        .map((change) => _toTextEdit(current.text, change))
        .toList(growable: false);
    return textEditApplier.apply(current, minimalEdits);
  }

  TextEdit _toTextEdit(String text, EditorTextChange change) => TextEdit(
    range: LspRange(
      start: _positionAt(text, change.start),
      end: _positionAt(text, change.start + change.removedLength),
    ),
    newText: change.insertedText,
  );

  LspPosition _positionAt(String text, int offset) {
    final boundedOffset = offset.clamp(0, text.length).toInt();
    final prefix = text.substring(0, boundedOffset);
    return LspPosition(
      line: '\n'.allMatches(prefix).length,
      character: boundedOffset - prefix.lastIndexOf('\n') - 1,
    );
  }
}
