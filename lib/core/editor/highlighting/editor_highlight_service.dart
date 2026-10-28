import '../../syntax/lexer/lexer_state.dart';
import '../../syntax/lexer/language_registry.dart';
import '../../syntax/model/token_metadata.dart';

class EditorHighlightService {
  static const _openingBrackets = {'(', '{', '['};
  static const _closingBrackets = {')', '}', ']'};
  static const _bracketPairs = {'(': ')', '{': '}', '[': ']'};

  final LanguageRegistry _languageRegistry;

  EditorHighlightService({LanguageRegistry? languageRegistry})
    : _languageRegistry = languageRegistry ?? LanguageRegistry();

  Set<int> matchingBracketOffsets(String filePath, String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return const {};
    final candidates = <int>[];
    if (cursor > 0) candidates.add(cursor - 1);
    if (cursor < text.length) candidates.add(cursor);

    final bracketOffsets = _bracketOffsets(filePath, text);
    final bracketsByOffset = {for (final entry in bracketOffsets) entry.$1: entry.$2};
    for (final offset in candidates) {
      final bracket = bracketsByOffset[offset];
      if (bracket == null) continue;
      final match = _findMatchingBracket(bracketOffsets, offset, bracket);
      if (match != null) return {offset, match};
    }
    return const {};
  }

  List<(int, String)> _bracketOffsets(String filePath, String text) {
    final lexer = _languageRegistry.getLexerForFile(filePath);
    final brackets = <(int, String)>[];
    var state = LexerState.initial;
    var lineStart = 0;
    for (final line in text.split('\n')) {
      final tokens = lexer.tokenizeLine(line, state);
      state = tokens.endState;
      for (var index = 0; index < tokens.tokens.count; index++) {
        if (!TokenMetadata.isBalancedBracket(
          tokens.tokens.getMetadata(index),
        )) {
          continue;
        }
        final start = tokens.tokens.getStartOffset(index);
        final end = tokens.tokens.getEndOffset(index);
        for (var column = start; column < end && column < line.length; column++) {
          final character = line[column];
          if (_openingBrackets.contains(character) ||
              _closingBrackets.contains(character)) {
            brackets.add((lineStart + column, character));
          }
        }
      }
      lineStart += line.length + 1;
    }
    return brackets;
  }

  int? _findMatchingBracket(
    List<(int, String)> brackets,
    int targetOffset,
    String target,
  ) {
    final targetIndex = brackets.indexWhere((bracket) => bracket.$1 == targetOffset);
    if (targetIndex < 0) return null;

    if (_openingBrackets.contains(target)) {
      final stack = <String>[];
      for (var index = targetIndex; index < brackets.length; index++) {
        final (offset, character) = brackets[index];
        if (_openingBrackets.contains(character)) {
          stack.add(character);
          continue;
        }
        if (stack.isNotEmpty &&
            _bracketPairs[stack.last] == character) {
          stack.removeLast();
          if (stack.isEmpty) return offset;
        }
      }
    } else {
      final stack = <String>[];
      for (var index = targetIndex; index >= 0; index--) {
        final (offset, character) = brackets[index];
        if (_closingBrackets.contains(character)) {
          stack.add(character);
          continue;
        }
        if (stack.isNotEmpty &&
            _bracketPairs[character] == stack.last) {
          stack.removeLast();
          if (stack.isEmpty) return offset;
        }
      }
    }
    return null;
  }

  List<(int, int)> matchingWordRanges(String text, int cursor) {
    if (text.isEmpty || cursor < 0 || cursor > text.length) return const [];
    final wordStart = _wordStartAt(text, cursor);
    if (wordStart == null) return const [];
    var wordEnd = wordStart;
    while (wordEnd < text.length && _isWordCharacter(text[wordEnd])) {
      wordEnd++;
    }
    final word = text.substring(wordStart, wordEnd);
    if (word.isEmpty) return const [];

    final ranges = <(int, int)>[];
    var searchFrom = 0;
    while (searchFrom < text.length) {
      final start = text.indexOf(word, searchFrom);
      if (start < 0) break;
      final end = start + word.length;
      if ((start == 0 || !_isWordCharacter(text[start - 1])) &&
          (end == text.length || !_isWordCharacter(text[end]))) {
        ranges.add((start, end));
      }
      searchFrom = end;
    }
    return ranges.length > 1 ? ranges : const [];
  }

  int? _wordStartAt(String text, int cursor) {
    var index = cursor < text.length && _isWordCharacter(text[cursor])
        ? cursor
        : cursor - 1;
    if (index < 0 || !_isWordCharacter(text[index])) return null;
    while (index > 0 && _isWordCharacter(text[index - 1])) {
      index--;
    }
    return index;
  }

  bool _isWordCharacter(String character) =>
      RegExp(r'[\p{L}\p{N}_$]', unicode: true).hasMatch(character);
}
