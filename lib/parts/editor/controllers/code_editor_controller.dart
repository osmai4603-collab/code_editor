import 'package:flutter/material.dart';
import '../../../core/lsp/diagnostics/diagnostics_service.dart';
import '../../../core/lsp/protocol/lsp_semantic_tokens_types.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/syntax/brackets/bracket_colorizer.dart';
import '../../../core/syntax/lexer/language_registry.dart';
import '../../../core/syntax/lexer/lexer_state.dart';
import '../../../core/syntax/lexer/rule_based_lexer.dart';
import '../../../core/syntax/model/line_tokens.dart';
import '../../../core/syntax/model/token_metadata.dart';
import '../../../core/syntax/semantic/semantic_tokens_merger.dart';
import '../../../core/syntax/semantic/sparse_tokens_store.dart';
import '../../../core/syntax/theme/editor_token_theme.dart';

/// محكم تحرير الكود المخصص عالي الأداء مع التلوين النحوي والدلالي
class CodeEditorController extends TextEditingController {
  final String filePath;
  final EditorTokenTheme theme;
  final LanguageRegistry _languageRegistry = LanguageRegistry();
  late RuleBasedLexer _lexer;

  final SparseTokensStore _semanticTokensStore = SparseTokensStore();
  DiagnosticsService? diagnosticsService;

  CodeEditorController({
    super.text,
    required this.filePath,
    EditorTokenTheme? theme,
    this.diagnosticsService,
  }) : theme = theme ?? EditorTokenTheme.dark() {
    _lexer = _languageRegistry.getLexerForFile(filePath);
  }

  /// تحديث الرموز الدلالية عند استلامها من خادم اللغة
  void updateSemanticTokens(List<DecodedSemanticToken> tokens, [String? resultId]) {
    _semanticTokensStore.setTokens(tokens, resultId);
    notifyListeners();
  }

  /// مسح الرموز الدلالية
  void clearSemanticTokens() {
    _semanticTokensStore.clear();
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = text;
    if (fullText.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final lines = fullText.split('\n');
    final children = <InlineSpan>[];

    LexerState lexerState = LexerState.initial;
    BracketStackState bracketState = BracketStackState.empty;

    // استخراج أخطاء الملف الحالي إن وجدت
    final diagnostics = diagnosticsService?.getForUri(filePath) ?? [];
    final errorsByLine = <int, List<DiagnosticItem>>{};
    for (final d in diagnostics) {
      final lineIdx = d.range.start.line;
      errorsByLine.putIfAbsent(lineIdx, () => []).add(d);
    }

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final lineText = lines[lineIndex];

      // 1. التلوين النحوي السريع للسطر (Syntactic Lexing)
      final lexResult = _lexer.tokenizeLine(lineText, lexerState);
      lexerState = lexResult.endState;
      LineTokens currentTokens = lexResult.tokens;

      // 2. دمج الرموز الدلالية (LSP Semantic Overlay) إن توفرت
      final semanticLine = _semanticTokensStore.getTokensForLine(lineIndex);
      if (semanticLine != null && semanticLine.isNotEmpty) {
        currentTokens = SemanticTokensMerger.merge(currentTokens, semanticLine);
      }

      // 3. تلوين أزواج الأقواس المتداخلة (Bracket Pairs)
      final bracketResult = BracketColorizer.colorizeLine(
        lineText,
        currentTokens,
        bracketState,
      );
      currentTokens = bracketResult.tokens;
      bracketState = bracketResult.endState;

      // 4. استخراج أخطاء هذا السطر لتطبيق الخطوط المتعرجة
      final lineErrors = errorsByLine[lineIndex];

      // 5. تحويل الرموز الثنائية إلى TextSpans مع الأنماط المخزنة
      final tokenCount = currentTokens.count;
      int lastOffset = 0;

      for (int t = 0; t < tokenCount; t++) {
        final endOffset = currentTokens.getEndOffset(t).clamp(0, lineText.length);
        if (endOffset <= lastOffset) continue;

        final chunkText = lineText.substring(lastOffset, endOffset);
        final meta = currentTokens.getMetadata(t);
        final fgColorId = TokenMetadata.getForeground(meta);
        final fontStyle = TokenMetadata.getFontStyle(meta);

        // هل يتقاطع هذا الرمز مع أي خطأ تشخيصي في السطر؟
        final hasError = lineErrors != null &&
            lineErrors.any((diag) {
              final startCol = diag.range.start.character;
              final endCol = diag.range.end.character;
              return startCol < endOffset && endCol > lastOffset;
            });

        TextStyle chunkStyle = theme.getStyle(fgColorId, fontStyle);
        if (hasError) {
          chunkStyle = chunkStyle.copyWith(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: Colors.redAccent,
          );
        }

        children.add(TextSpan(
          text: chunkText,
          style: chunkStyle,
        ));

        lastOffset = endOffset;
      }

      // إضافة المتبقي من السطر إن وجد
      if (lastOffset < lineText.length) {
        children.add(TextSpan(
          text: lineText.substring(lastOffset),
          style: theme.getStyle(0, 0),
        ));
      }

      // إضافة فاصل السطر الجديد ما لم نكن في آخر سطر
      if (lineIndex < lines.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(
      style: style,
      children: children,
    );
  }
}
