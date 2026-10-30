import 'package:flutter/services.dart';

import 'editor_indentation_options.dart';
import 'indentation_service.dart';
import 'indentation_syntax_context.dart';
import 'indentation_text_change.dart';
import 'language_indentation_rules.dart';
import 'whitespace_only_line_backspace.dart';
import '../../languages/definitions/built_in_languages.dart';

class EditorInputFormatter extends TextInputFormatter {
  static final _newlineInputPattern = RegExp(r'^\r?\n[ \t]*$');

  final EditorIndentationOptions options;
  final String languageId;
  final bool autoIndent;
  final bool autoClosingPairs;
  final void Function(String character)? onCharacterTyped;
  final LanguageIndentationRules indentationRules;
  final IndentationService _indentationService;
  late final IndentationSyntaxContext _syntaxContext = IndentationSyntaxContext(
    languageId,
  );

  EditorInputFormatter({
    required this.options,
    required this.languageId,
    this.autoIndent = true,
    this.autoClosingPairs = true,
    this.onCharacterTyped,
    LanguageIndentationRules? indentationRules,
    this._indentationService = const IndentationService(),
  }) : indentationRules =
           indentationRules ??
           builtInLanguageDefinitionForId(languageId)?.indentationRules ??
           const BracketIndentationRules();

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

    final change = IndentationTextChange.between(oldValue, newValue);
    if (change == null) return newValue;
    final inserted = change.insertedText;
    final backspaceResult = joinWhitespaceOnlyLineOnBackspace(
      oldValue,
      oldSelection,
      change,
    );
    if (backspaceResult != null) return backspaceResult;

    if (oldSelection.isCollapsed &&
        change.removedLength == 0 &&
        inserted.length == 1 &&
        inserted != '\n') {
      onCharacterTyped?.call(inserted);
    }

    if (_newlineInputPattern.hasMatch(inserted) && autoIndent) {
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

    if (!autoClosingPairs ||
        !_isOpeningPair(character) ||
        !_syntaxContext.isCode(oldValue.text, oldSelection.extentOffset)) {
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
    final lineStart = _syntaxContext.lineStart(text, start);
    final linePrefix = text.substring(lineStart, start);
    final baseIndent = _indentationService.indentationOf(linePrefix);
    final previous = _lastNonWhitespace(linePrefix);
    final next = end < text.length ? text[end] : '';

    final codeContext = _syntaxContext.isCode(text, start);
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
    if (codeContext && _shouldIncreaseIndent(linePrefix)) {
      indent += options.indentUnit;
    } else if (codeContext &&
        linePrefix.trim().isEmpty &&
        _isStructuralClosingPair(next) &&
        _syntaxContext.hasMatchingOpeningBracket(text, start, next)) {
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

  bool _shouldIncreaseIndent(String linePrefix) =>
      indentationRules.shouldIndentAfterLine(linePrefix);

  String _lastNonWhitespace(String value) {
    for (var index = value.length - 1; index >= 0; index--) {
      if (value[index].trim().isNotEmpty) return value[index];
    }
    return '';
  }

  bool _isOpeningPair(String character) =>
      indentationRules.autoClosePairs.any((pair) => pair.startsWith(character));

  bool _isClosingPair(String character) =>
      indentationRules.autoClosePairs.any((pair) => pair.endsWith(character));

  bool _isStructuralClosingPair(String character) =>
      const {')', ']', '}'}.contains(character);

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

  String _closingFor(String opening) {
    for (final pair in indentationRules.autoClosePairs) {
      if (pair.startsWith(opening)) return pair.substring(opening.length);
    }
    return '';
  }
}
