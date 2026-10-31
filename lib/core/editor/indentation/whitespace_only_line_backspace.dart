import 'package:flutter/services.dart';

import 'indentation_text_change.dart';

TextEditingValue? joinWhitespaceOnlyLineOnBackspace(
  TextEditingValue oldValue,
  TextSelection selection,
  IndentationTextChange change,
) {
  if (!selection.isCollapsed ||
      change.insertedText.isNotEmpty ||
      change.removedLength != 1 ||
      change.startOffset != selection.extentOffset - 1) {
    return null;
  }

  return removeWhitespaceOnlyLineOnBackspace(oldValue, selection);
}

TextEditingValue? removeWhitespaceOnlyLineOnBackspace(
  TextEditingValue value,
  TextSelection selection,
) {
  if (!selection.isValid ||
      !selection.isCollapsed ||
      selection.extentOffset > value.text.length) {
    return null;
  }

  final text = value.text;
  final lineStart = text.lastIndexOf('\n', selection.extentOffset - 1) + 1;
  if (lineStart == 0) return null;
  final lineEnd = text.indexOf('\n', lineStart);
  final contentEnd = lineEnd < 0 ? text.length : lineEnd;
  if (text.substring(lineStart, contentEnd).trim().isNotEmpty) return null;

  var removalStart = lineStart - 1;
  if (removalStart > 0 && text[removalStart - 1] == '\r') {
    removalStart--;
  }
  return TextEditingValue(
    text: text.replaceRange(removalStart, contentEnd, ''),
    selection: TextSelection.collapsed(offset: removalStart),
  );
}
