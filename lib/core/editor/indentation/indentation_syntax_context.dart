/// Identifies comments, strings, and bracket pairs around an edit position.
class IndentationSyntaxContext {
  final String languageId;

  const IndentationSyntaxContext(this.languageId);

  bool isCode(String text, int cursor) {
    final start = lineStart(text, cursor);
    final prefix = text.substring(start, cursor);
    String? quote;
    var escaped = false;
    for (var index = 0; index < prefix.length; index++) {
      final character = prefix[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (character == quote) {
          quote = null;
        }
      } else if (character == '"' || character == "'" || character == '`') {
        quote = character;
      } else if (character == '#' ||
          (character == '/' &&
              index + 1 < prefix.length &&
              prefix[index + 1] == '/')) {
        return false;
      }
    }
    return quote == null;
  }

  int lineStart(String text, int offset) =>
      offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

  bool hasMatchingOpeningBracket(String text, int cursor, String closing) {
    final opening = switch (closing) {
      ')' => '(',
      ']' => '[',
      '}' => '{',
      _ => '',
    };
    if (opening.isEmpty) return false;

    final brackets = <String>[];
    final normalizedLanguageId = languageId.toLowerCase();
    final hasHashComments = const {
      'python',
      'gdscript',
      'ruby',
      'shellscript',
      'yaml',
      'toml',
      'r',
      'perl',
    }.contains(normalizedLanguageId);
    final hasSlashComments =
        normalizedLanguageId != 'plaintext' && !hasHashComments;
    String? quote;
    var tripleQuote = false;
    var escaped = false;
    var lineComment = false;
    var blockComment = false;
    for (var index = 0; index < cursor; index++) {
      final character = text[index];
      final next = index + 1 < cursor ? text[index + 1] : '';

      if (lineComment) {
        if (character == '\n') lineComment = false;
        continue;
      }
      if (blockComment) {
        if (character == '*' && next == '/') {
          blockComment = false;
          index++;
        }
        continue;
      }
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (tripleQuote &&
            character == quote &&
            index + 2 < cursor &&
            text[index + 1] == quote &&
            text[index + 2] == quote) {
          quote = null;
          tripleQuote = false;
          index += 2;
        } else if (!tripleQuote && character == quote) {
          quote = null;
        }
        continue;
      }

      if (hasSlashComments && character == '/' && next == '/') {
        lineComment = true;
        index++;
      } else if (hasSlashComments && character == '/' && next == '*') {
        blockComment = true;
        index++;
      } else if (hasHashComments && character == '#') {
        lineComment = true;
      } else if ((character == '"' || character == "'") &&
          index + 2 < cursor &&
          text[index + 1] == character &&
          text[index + 2] == character) {
        quote = character;
        tripleQuote = true;
        index += 2;
      } else if (character == '"' || character == "'" || character == '`') {
        quote = character;
      } else if (const {'(', '[', '{'}.contains(character)) {
        brackets.add(character);
      } else if (_isClosingBracket(character) &&
          brackets.isNotEmpty &&
          _matchingClosingPair(brackets.last) == character) {
        brackets.removeLast();
      }
    }

    return brackets.isNotEmpty && brackets.last == opening;
  }

  bool _isClosingBracket(String character) =>
      const {')', ']', '}'}.contains(character);

  String _matchingClosingPair(String opening) => switch (opening) {
    '(' => ')',
    '[' => ']',
    '{' => '}',
    _ => '',
  };
}
