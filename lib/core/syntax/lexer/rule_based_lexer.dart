import 'dart:typed_data';
import '../model/encoded_token_attributes.dart';
import '../model/line_tokens.dart';
import '../model/token_metadata.dart';
import '../theme/token_color_palette.dart';
import 'language_syntax_definition.dart';
import 'lexer_state.dart';

/// نتيجة تحليل السطر: الرموز والحالة الناتجة لنهاية السطر
class TokenizeLineResult {
  final LineTokens tokens;
  final LexerState endState;

  const TokenizeLineResult({required this.tokens, required this.endState});
}

/// محلل نحوي عام قائم على القواعد وخالٍ تماماً من أي اعتماديات خارجية (Language-Agnostic Lexer)
class RuleBasedLexer {
  final LanguageSyntaxDefinition definition;

  const RuleBasedLexer(this.definition);

  TokenizeLineResult tokenizeLine(String line, [LexerState state = LexerState.initial]) {
    final len = line.length;
    if (len == 0) {
      return TokenizeLineResult(
        tokens: LineTokens.empty(0),
        endState: state,
      );
    }

    final rawTokens = <int>[];
    int cursor = 0;
    int lastEnd = 0;

    void emitToken(int endOffset, int metadata) {
      if (endOffset <= lastEnd) return;
      lastEnd = endOffset;
      rawTokens.add(endOffset);
      rawTokens.add(metadata);
    }

    int makeMeta({
      required int foreground,
      StandardTokenType tokenType = StandardTokenType.other,
      int fontStyle = FontStyleMask.none,
      bool isBracket = false,
    }) {
      return TokenMetadata.encode(
        foreground: foreground,
        tokenType: tokenType,
        fontStyle: fontStyle,
        isBalancedBracket: isBracket,
      );
    }

    bool inBlockComment = state.inBlockComment;
    String? inMultiString = state.inMultilineStringDelimiter;

    // 1. التعامل مع استمرار تعليق كتلي من سطر سابق /* ...
    if (inBlockComment) {
      final endIdx = definition.blockCommentEnd != null
          ? line.indexOf(definition.blockCommentEnd!, cursor)
          : -1;

      if (endIdx != -1) {
        final commentEnd = endIdx + definition.blockCommentEnd!.length;
        emitToken(commentEnd, makeMeta(
          foreground: StandardColorId.comment,
          tokenType: StandardTokenType.comment,
          fontStyle: FontStyleMask.italic,
        ));
        cursor = commentEnd;
        inBlockComment = false;
      } else {
        // كامل السطر لا يزال تعليقاً كتلياً
        emitToken(len, makeMeta(
          foreground: StandardColorId.comment,
          tokenType: StandardTokenType.comment,
          fontStyle: FontStyleMask.italic,
        ));
        return TokenizeLineResult(
          tokens: LineTokens(binaryTokens: Int32List.fromList(rawTokens), lineLength: len),
          endState: const LexerState(inBlockComment: true),
        );
      }
    }

    // 2. التعامل مع استمرار نص متعدد الأسطر من سطر سابق ''' أو """
    if (inMultiString != null) {
      final endIdx = line.indexOf(inMultiString, cursor);
      if (endIdx != -1) {
        final strEnd = endIdx + inMultiString.length;
        emitToken(strEnd, makeMeta(
          foreground: StandardColorId.stringLiteral,
          tokenType: StandardTokenType.string,
        ));
        cursor = strEnd;
        inMultiString = null;
      } else {
        emitToken(len, makeMeta(
          foreground: StandardColorId.stringLiteral,
          tokenType: StandardTokenType.string,
        ));
        return TokenizeLineResult(
          tokens: LineTokens(binaryTokens: Int32List.fromList(rawTokens), lineLength: len),
          endState: LexerState(inMultilineStringDelimiter: inMultiString),
        );
      }
    }

    // 3. المسح الحرفي للسطر
    while (cursor < len) {
      final code = line.codeUnitAt(cursor);

      // أ. المسافات البيضاء
      if (code <= 32) {
        while (cursor < len && line.codeUnitAt(cursor) <= 32) {
          cursor++;
        }
        emitToken(cursor, makeMeta(foreground: StandardColorId.defaultForeground));
        continue;
      }

      // ب. التعليقات التوثيقية والأحادية (Doc and Line Comments)
      if (definition.docCommentPrefix != null && line.startsWith(definition.docCommentPrefix!, cursor)) {
        emitToken(len, makeMeta(
          foreground: StandardColorId.comment,
          tokenType: StandardTokenType.comment,
          fontStyle: FontStyleMask.italic,
        ));
        cursor = len;
        break;
      }

      if (definition.lineCommentPrefix != null && line.startsWith(definition.lineCommentPrefix!, cursor)) {
        emitToken(len, makeMeta(
          foreground: StandardColorId.comment,
          tokenType: StandardTokenType.comment,
          fontStyle: FontStyleMask.italic,
        ));
        cursor = len;
        break;
      }

      // ج. بداية تعليق كتلي /*
      if (definition.blockCommentStart != null && line.startsWith(definition.blockCommentStart!, cursor)) {
        final endIdx = definition.blockCommentEnd != null
            ? line.indexOf(definition.blockCommentEnd!, cursor + definition.blockCommentStart!.length)
            : -1;

        if (endIdx != -1) {
          final commentEnd = endIdx + definition.blockCommentEnd!.length;
          emitToken(commentEnd, makeMeta(
            foreground: StandardColorId.comment,
            tokenType: StandardTokenType.comment,
            fontStyle: FontStyleMask.italic,
          ));
          cursor = commentEnd;
        } else {
          emitToken(len, makeMeta(
            foreground: StandardColorId.comment,
            tokenType: StandardTokenType.comment,
            fontStyle: FontStyleMask.italic,
          ));
          inBlockComment = true;
          cursor = len;
          break;
        }
        continue;
      }

      // د. النصوص متعددة الأسطر (Triple Quotes """ or ''')
      if (cursor + 3 <= len) {
        final sub3 = line.substring(cursor, cursor + 3);
        if (sub3 == '"""' || sub3 == "'''") {
          cursor += 3;
          final endIdx = line.indexOf(sub3, cursor);
          if (endIdx != -1) {
            cursor = endIdx + 3;
            emitToken(cursor, makeMeta(
              foreground: StandardColorId.stringLiteral,
              tokenType: StandardTokenType.string,
            ));
          } else {
            inMultiString = sub3;
            emitToken(len, makeMeta(
              foreground: StandardColorId.stringLiteral,
              tokenType: StandardTokenType.string,
            ));
            cursor = len;
            break;
          }
          continue;
        }
      }

      // هـ. النصوص المفردة والمزدوجة العادية ('...' or "...")
      if (code == 34 || code == 39) { // " or '
        final quote = code;
        cursor++;
        while (cursor < len) {
          final ch = line.codeUnitAt(cursor);
          if (ch == 92) { // escape \
            cursor += 2;
            continue;
          }
          if (ch == quote) {
            cursor++;
            break;
          }
          cursor++;
        }
        emitToken(cursor, makeMeta(
          foreground: StandardColorId.stringLiteral,
          tokenType: StandardTokenType.string,
        ));
        continue;
      }

      // و. الأرقام (Numbers: 0x..., 123.45, etc.)
      if (_isDigit(code) || (code == 46 && cursor + 1 < len && _isDigit(line.codeUnitAt(cursor + 1)))) {
        if (code == 48 && cursor + 1 < len && (line.codeUnitAt(cursor + 1) == 120 || line.codeUnitAt(cursor + 1) == 88)) { // 0x
          cursor += 2;
          while (cursor < len && _isHexDigit(line.codeUnitAt(cursor))) {
            cursor++;
          }
        } else {
          while (cursor < len && (_isDigit(line.codeUnitAt(cursor)) || line.codeUnitAt(cursor) == 46)) { // digits and dot
            cursor++;
          }
        }
        emitToken(cursor, makeMeta(foreground: StandardColorId.number));
        continue;
      }

      // ز. المعرفات والكلمات المحجوزة (Identifiers / Keywords)
      if (_isIdentifierStart(code)) {
        final start = cursor;
        while (cursor < len && _isIdentifierPart(line.codeUnitAt(cursor))) {
          cursor++;
        }
        final word = line.substring(start, cursor);

        // فحص هل تلي الكلمة قوس فتح استدعاء دالة
        int nextNonSpace = cursor;
        while (nextNonSpace < len && line.codeUnitAt(nextNonSpace) <= 32) {
          nextNonSpace++;
        }
        final isFuncCall = nextNonSpace < len && line.codeUnitAt(nextNonSpace) == 40; // (

        int fg = StandardColorId.defaultForeground;
        int style = FontStyleMask.none;

        if (definition.controlKeywords.contains(word)) {
          fg = StandardColorId.controlKeyword;
          style = FontStyleMask.bold;
        } else if (definition.keywords.contains(word)) {
          fg = StandardColorId.keyword;
        } else if (definition.typeKeywords.contains(word)) {
          fg = StandardColorId.type;
        } else if (definition.constantKeywords.contains(word)) {
          fg = StandardColorId.constant;
        } else if (_isPascalCase(word)) {
          // أسماء الفئات والأنواع المخصصة تبدأ بحرف كبير
          fg = StandardColorId.type;
        } else if (isFuncCall) {
          fg = StandardColorId.function;
        }

        emitToken(cursor, makeMeta(foreground: fg, fontStyle: style));
        continue;
      }

      // ح. الأقواس () [] {}
      if (definition.bracketCharacters.contains(code)) {
        cursor++;
        emitToken(cursor, makeMeta(
          foreground: StandardColorId.operator,
          isBracket: true,
        ));
        continue;
      }

      // ط. المعاملات والعمليات الحسابية والمنطقية
      if (definition.operatorCharacters.contains(code)) {
        while (cursor < len && definition.operatorCharacters.contains(line.codeUnitAt(cursor))) {
          cursor++;
        }
        emitToken(cursor, makeMeta(foreground: StandardColorId.operator));
        continue;
      }

      // ي. أي رمز آخر غير معروف
      cursor++;
      emitToken(cursor, makeMeta(foreground: StandardColorId.defaultForeground));
    }

    return TokenizeLineResult(
      tokens: LineTokens(binaryTokens: Int32List.fromList(rawTokens), lineLength: len),
      endState: LexerState(
        inBlockComment: inBlockComment,
        inMultilineStringDelimiter: inMultiString,
      ),
    );
  }

  static bool _isDigit(int code) => code >= 48 && code <= 57;

  static bool _isHexDigit(int code) =>
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 70) ||
      (code >= 97 && code <= 102);

  static bool _isIdentifierStart(int code) =>
      (code >= 65 && code <= 90) || // A-Z
      (code >= 97 && code <= 122) || // a-z
      code == 95 || // _
      code == 36; // $

  static bool _isIdentifierPart(int code) =>
      _isIdentifierStart(code) || _isDigit(code);

  static bool _isPascalCase(String word) {
    if (word.isEmpty) return false;
    final first = word.codeUnitAt(0);
    return first >= 65 && first <= 90; // A-Z
  }
}
