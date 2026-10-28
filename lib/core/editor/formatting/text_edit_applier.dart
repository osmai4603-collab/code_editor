import 'package:flutter/services.dart';

import '../../lsp/protocol/lsp_types.dart';

class TextEditApplier {
  const TextEditApplier();

  TextEditingValue apply(TextEditingValue current, List<TextEdit> edits) {
    final resolved = edits.map((edit) {
      final start = _offsetAt(current.text, edit.range.start);
      final end = _offsetAt(current.text, edit.range.end);
      if (start > end) {
        throw FormatException('Text edit range starts after it ends');
      }
      return _ResolvedTextEdit(start: start, end: end, newText: edit.newText);
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    for (var index = 1; index < resolved.length; index++) {
      final previous = resolved[index - 1];
      final next = resolved[index];
      if (next.start < previous.end ||
          (next.start == previous.start &&
              (previous.start == previous.end || next.start == next.end))) {
        throw FormatException('Text edits contain overlapping ranges');
      }
    }

    var text = current.text;
    for (final edit in resolved.reversed) {
      text = text.replaceRange(edit.start, edit.end, edit.newText);
    }

    final selection = current.selection;
    if (!selection.isValid) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: _mapOffset(selection.baseOffset, resolved),
        extentOffset: _mapOffset(selection.extentOffset, resolved),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
    );
  }

  int _offsetAt(String text, LspPosition position) {
    if (position.line < 0 || position.character < 0) {
      throw FormatException('Text edit positions cannot be negative');
    }
    final lines = text.split('\n');
    if (position.line >= lines.length) {
      throw FormatException('Text edit position is outside the document');
    }
    final line = lines[position.line];
    final contentLength = line.endsWith('\r') ? line.length - 1 : line.length;
    if (position.character > contentLength) {
      throw FormatException('Text edit position is outside the document');
    }
    var offset = 0;
    for (var line = 0; line < position.line; line++) {
      offset += lines[line].length + 1;
    }
    return offset + position.character;
  }

  int _mapOffset(int offset, List<_ResolvedTextEdit> edits) {
    var shift = 0;
    for (final edit in edits) {
      if (offset <= edit.start) return offset + shift;
      if (offset <= edit.end) {
        return edit.start + shift + edit.newText.length;
      }
      shift += edit.newText.length - (edit.end - edit.start);
    }
    return offset + shift;
  }
}

class _ResolvedTextEdit {
  final int start;
  final int end;
  final String newText;

  const _ResolvedTextEdit({
    required this.start,
    required this.end,
    required this.newText,
  });
}
