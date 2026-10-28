import 'package:flutter/services.dart';

import 'editor_indentation_options.dart';
import 'indentation_service.dart';

class EditorInputFormatter extends TextInputFormatter {
  final EditorIndentationOptions options;
  final String languageId;
  final bool autoIndent;
  final bool autoClosingPairs;
  final IndentationService _indentationService;

  EditorInputFormatter({
    required this.options,
    required this.languageId,
    this.autoIndent = true,
    this.autoClosingPairs = true,
    this._indentationService = const IndentationService(),
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldSelection = oldValue.selection;
    if (!oldSelection.isValid ||
        oldSelection.start < 0 ||
        oldSelection.end > oldValue.text.length) {
      return newValue;
    }

    final change = _singleChange(oldValue, newValue);
    if (change == null) return newValue;
    final inserted = change.insertedText;

    if (inserted == '\n' && autoIndent) {
      return _insertNewline(oldValue, oldSelection);
    }
    if (inserted.length != 1 || oldSelection.isCollapsed == false) {
      if (autoClosingPairs &&
          inserted.length == 1 &&
          _isOpeningPair(inserted) &&
          oldSelection.isValid &&
          oldSelection.start != oldSelection.end) {
        return _wrapSelection(oldValue, oldSelection, inserted);
      }
      return newValue;
    }

    final character = inserted;
    if (autoClosingPairs && _isClosingPair(character)) {
      final cursor = oldSelection.extentOffset;
      if (cursor < oldValue.text.length && oldValue.text[cursor] == character) {
        return TextEditingValue(
          text: oldValue.text,
          selection: TextSelection.collapsed(offset: cursor + 1),
        );
      }
    }

    if (autoClosingPairs &&
        _isStructuralClosingPair(character) &&
        _isCodeContext(oldValue.text, oldSelection.extentOffset)) {
      final cursor = oldSelection.extentOffset;
      final lineStart = _lineStart(oldValue.text, cursor);
      final linePrefix = oldValue.text.substring(lineStart, cursor);
      if (linePrefix.trim().isEmpty &&
          _hasMatchingOpeningBracket(oldValue.text, cursor, character)) {
        final indent = _indentationService.indentationOf(linePrefix);
        final outdented = _removeOneIndent(indent);
        final updated = oldValue.text.replaceRange(
          lineStart,
          cursor,
          outdented + character,
        );
        return TextEditingValue(
          text: updated,
          selection: TextSelection.collapsed(
            offset: lineStart + outdented.length + 1,
          ),
        );
      }
    }

    if (!autoClosingPairs ||
        !_isOpeningPair(character) ||
        !_isCodeContext(oldValue.text, oldSelection.extentOffset)) {
      return newValue;
    }

    final cursor = oldSelection.extentOffset;
    final close = _closingFor(character);
    final text = oldValue.text.replaceRange(cursor, cursor, '$character$close');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor + 1),
    );
  }

  TextEditingValue _insertNewline(
    TextEditingValue oldValue,
    TextSelection selection,
  ) {
    final text = oldValue.text;
    final start = selection.start;
    final end = selection.end;
    final lineStart = _lineStart(text, start);
    final linePrefix = text.substring(lineStart, start);
    final baseIndent = _indentationService.indentationOf(linePrefix);
    final previous = _lastNonWhitespace(linePrefix);
    final next = end < text.length ? text[end] : '';

    final codeContext = _isCodeContext(text, start);
    if (_matchingClosingPair(previous) == next &&
        next.isNotEmpty &&
        codeContext) {
      final replacement = '\n$baseIndent${options.indentUnit}\n$baseIndent';
      final updated = text.replaceRange(start, end, replacement);
      return TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(
          offset: start + 1 + baseIndent.length + options.indentUnit.length,
        ),
      );
    }

    var indent = baseIndent;
    if (codeContext && _shouldIncreaseIndent(previous, linePrefix)) {
      indent += options.indentUnit;
    } else if (codeContext &&
        linePrefix.trim().isEmpty &&
        _isStructuralClosingPair(next) &&
        _hasMatchingOpeningBracket(text, start, next)) {
      indent = _removeOneIndent(indent);
    }

    final updated = text.replaceRange(start, end, '\n$indent');
    return TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1 + indent.length),
    );
  }

  TextEditingValue _wrapSelection(
    TextEditingValue oldValue,
    TextSelection selection,
    String opening,
  ) {
    final start = selection.start;
    final end = selection.end;
    final selected = oldValue.text.substring(start, end);
    final replacement = '$opening$selected${_closingFor(opening)}';
    final isReversed = selection.baseOffset > selection.extentOffset;
    return TextEditingValue(
      text: oldValue.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: isReversed ? start + 1 + selected.length : start + 1,
        extentOffset: isReversed ? start + 1 : start + 1 + selected.length,
        isDirectional: selection.isDirectional,
      ),
    );
  }

  bool _shouldIncreaseIndent(String previous, String linePrefix) =>
      const {'{', '[', '('}.contains(previous) ||
      (languageId.toLowerCase() == 'python' &&
          linePrefix.trimRight().endsWith(':'));

  bool _isCodeContext(String text, int cursor) {
    final lineStart = _lineStart(text, cursor);
    final prefix = text.substring(lineStart, cursor);
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

  String _lastNonWhitespace(String value) {
    for (var index = value.length - 1; index >= 0; index--) {
      if (value[index].trim().isNotEmpty) return value[index];
    }
    return '';
  }

  int _lineStart(String text, int offset) =>
      offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

  bool _isOpeningPair(String character) =>
      const {'(', '[', '{', '"', "'", '`'}.contains(character);

  bool _isClosingPair(String character) =>
      _isStructuralClosingPair(character) ||
      const {'"', "'", '`'}.contains(character);

  bool _isStructuralClosingPair(String character) =>
      const {')', ']', '}'}.contains(character);

  bool _hasMatchingOpeningBracket(
    String text,
    int cursor,
    String closing,
  ) {
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
      } else if (_isStructuralClosingPair(character) &&
          brackets.isNotEmpty &&
          _matchingClosingPair(brackets.last) == character) {
        brackets.removeLast();
      }
    }

    return brackets.isNotEmpty && brackets.last == opening;
  }

  String _removeOneIndent(String indent) {
    if (indent.endsWith('\t')) return indent.substring(0, indent.length - 1);
    final spaces = indent.length - indent.trimLeft().length;
    final count = spaces < options.indentSize ? spaces : options.indentSize;
    return indent.substring(0, indent.length - count);
  }

  String _matchingClosingPair(String opening) => switch (opening) {
    '(' => ')',
    '[' => ']',
    '{' => '}',
    _ => '',
  };

  String _closingFor(String opening) => switch (opening) {
    '(' => ')',
    '[' => ']',
    '{' => '}',
    '"' => '"',
    "'" => "'",
    '`' => '`',
    _ => '',
  };

  _TextChange? _singleChange(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    final cursor = oldValue.selection.extentOffset;
    if (oldValue.selection.isCollapsed &&
        newText.length == oldText.length + 1 &&
        newText.startsWith(oldText.substring(0, cursor)) &&
        newText.endsWith(oldText.substring(cursor))) {
      return _TextChange(newText.substring(cursor, cursor + 1));
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
    return _TextChange(newText.substring(prefix, newEnd));
  }
}

class _TextChange {
  final String insertedText;

  const _TextChange(this.insertedText);
}
