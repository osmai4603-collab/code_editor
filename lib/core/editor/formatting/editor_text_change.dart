class EditorTextChange {
  final int start;
  final int removedLength;
  final String insertedText;

  const EditorTextChange({
    required this.start,
    required this.removedLength,
    required this.insertedText,
  });

  static EditorTextChange? between(String oldText, String newText) {
    if (oldText == newText) return null;

    var prefix = 0;
    final sharedLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < sharedLength && oldText[prefix] == newText[prefix]) {
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

    return EditorTextChange(
      start: prefix,
      removedLength: oldEnd - prefix,
      insertedText: newText.substring(prefix, newEnd),
    );
  }
}
