import 'package:flutter/services.dart';

/// Describes the inserted and removed text between two editing values.
class IndentationTextChange {
  final String insertedText;
  final int removedLength;

  const IndentationTextChange({
    required this.insertedText,
    required this.removedLength,
  });

  static IndentationTextChange? between(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    if (oldValue.selection.isCollapsed) {
      final cursor = oldValue.selection.extentOffset;
      if (newText.length == oldText.length + 1 &&
          newText.startsWith(oldText.substring(0, cursor)) &&
          newText.endsWith(oldText.substring(cursor))) {
        return IndentationTextChange(
          insertedText: newText.substring(cursor, cursor + 1),
          removedLength: 0,
        );
      }
    }

    var prefix = 0;
    final maxPrefix = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > prefix &&
        newEnd > prefix &&
        oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    return IndentationTextChange(
      insertedText: newText.substring(prefix, newEnd),
      removedLength: oldEnd - prefix,
    );
  }
}
