import 'package:flutter/material.dart';
import '../../../core/editor/highlighting/editor_highlight_service.dart';
import '../../../core/lsp/diagnostics/diagnostics_service.dart';
import '../../../core/lsp/diagnostics/diagnostic_range_utils.dart';
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
import '../../../core/theme/editor_theme.dart';

/// محكم تحرير الكود المخصص عالي الأداء مع التلوين النحوي والدلالي
class CodeEditorController extends TextEditingController {
  final String filePath;
  final EditorTokenTheme theme;
  final LanguageRegistry _languageRegistry = LanguageRegistry();
  final EditorHighlightService _highlightService = EditorHighlightService();
  late RuleBasedLexer _lexer;

  final SparseTokensStore _semanticTokensStore = SparseTokensStore();
  DiagnosticsService? _diagnosticsService;
  DiagnosticsService? get diagnosticsService => _diagnosticsService;

  set diagnosticsService(DiagnosticsService? service) {
    if (identical(_diagnosticsService, service)) return;
    _diagnosticsService?.removeListener(_onDiagnosticsChanged);
    _diagnosticsService = service;
    _diagnosticsService?.addListener(_onDiagnosticsChanged);
    notifyListeners();
  }

  CodeEditorController({
    super.text,
    required this.filePath,
    EditorTokenTheme? theme,
    DiagnosticsService? diagnosticsService,
  }) : theme = theme ?? EditorTokenTheme.dark() {
    _diagnosticsService = diagnosticsService;
    _lexer = _languageRegistry.getLexerForFile(filePath);
    _diagnosticsService?.addListener(_onDiagnosticsChanged);
  }

  void _onDiagnosticsChanged() => notifyListeners();

  @override
  void dispose() {
    _diagnosticsService?.removeListener(_onDiagnosticsChanged);
    super.dispose();
  }

  /// تحديث الرموز الدلالية عند استلامها من خادم اللغة
  void updateSemanticTokens(
    List<DecodedSemanticToken> tokens, [
    String? resultId,
  ]) {
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
    final cursor = selection.isValid
        ? selection.extentOffset.clamp(0, fullText.length).toInt()
        : -1;
    final matchingBrackets = _highlightService.matchingBracketOffsets(
      filePath,
      fullText,
      cursor,
    );
    final matchingWords = _highlightService.matchingWordRanges(
      fullText,
      cursor,
    );

    LexerState lexerState = LexerState.initial;
    BracketStackState bracketState = BracketStackState.empty;

    // استخراج أخطاء الملف الحالي إن وجدت
    final diagnostics = _diagnosticsService?.getForUri(filePath) ?? [];
    final diagnosticsByLine = <int, List<DiagnosticItem>>{};
    for (final diagnostic in diagnostics) {
      final startLine = diagnostic.range.start.line
          .clamp(0, lines.length - 1)
          .toInt();
      final lastLine = DiagnosticRangeUtils.lastCoveredLine(
        diagnostic.range,
      ).clamp(startLine, lines.length - 1).toInt();
      for (var line = startLine; line <= lastLine; line++) {
        diagnosticsByLine.putIfAbsent(line, () => []).add(diagnostic);
      }
    }
    final editorTheme = EditorTheme.of(context);
    var absoluteLineStart = 0;

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
      final lineDiagnostics = diagnosticsByLine[lineIndex] ?? const [];

      // 5. تحويل الرموز الثنائية إلى TextSpans مع الأنماط المخزنة
      final tokenCount = currentTokens.count;
      int lastOffset = 0;
      final sortedLineDiagnostics = lineDiagnostics.toList()
        ..sort(
          (a, b) => a.range.start.character.compareTo(b.range.start.character),
        );

      for (int t = 0; t < tokenCount; t++) {
        final endOffset = currentTokens
            .getEndOffset(t)
            .clamp(0, lineText.length);
        if (endOffset <= lastOffset) continue;

        final meta = currentTokens.getMetadata(t);
        final fgColorId = TokenMetadata.getForeground(meta);
        final fontStyle = TokenMetadata.getFontStyle(meta);
        final boundaries = <int>{lastOffset, endOffset};
        for (final diagnostic in sortedLineDiagnostics) {
          final bounds = DiagnosticRangeUtils.boundsForLine(
            diagnostic.range,
            lineIndex,
            lineText.length,
          );
          if (bounds == null) continue;
          if (bounds[0] > lastOffset && bounds[0] < endOffset) {
            boundaries.add(bounds[0]);
          }
          for (final offset in matchingBrackets) {
            final localOffset = offset - absoluteLineStart;
            if (localOffset > lastOffset && localOffset < endOffset) {
              boundaries.add(localOffset);
            }
            if (localOffset + 1 > lastOffset && localOffset + 1 < endOffset) {
              boundaries.add(localOffset + 1);
            }
          }
          for (final (start, end) in matchingWords) {
            final localStart = start - absoluteLineStart;
            final localEnd = end - absoluteLineStart;
            if (localStart > lastOffset && localStart < endOffset) {
              boundaries.add(localStart);
            }
            if (localEnd > lastOffset && localEnd < endOffset) {
              boundaries.add(localEnd);
            }
          }
          if (bounds[1] > lastOffset && bounds[1] < endOffset) {
            boundaries.add(bounds[1]);
          }
        }
        final sortedBoundaries = boundaries.toList()..sort();
        for (
          var boundary = 0;
          boundary < sortedBoundaries.length - 1;
          boundary++
        ) {
          final segmentStart = sortedBoundaries[boundary];
          final segmentEnd = sortedBoundaries[boundary + 1];
          if (segmentEnd <= segmentStart) continue;
          final severity = DiagnosticRangeUtils.highestSeverityForLineSegment(
            diagnostics: lineDiagnostics,
            line: lineIndex,
            segmentStart: segmentStart,
            segmentEnd: segmentEnd,
            lineLength: lineText.length,
          );
          var chunkStyle = theme.getStyle(fgColorId, fontStyle);
          if (severity != null) {
            chunkStyle = chunkStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: editorTheme.diagnosticColor(severity),
            );
          }
          final absoluteStart = absoluteLineStart + segmentStart;
          final absoluteEnd = absoluteLineStart + segmentEnd;
          if (matchingBrackets.contains(absoluteStart) &&
              absoluteEnd == absoluteStart + 1) {
            chunkStyle = chunkStyle.copyWith(
              backgroundColor: Colors.orange.withValues(alpha: 0.28),
            );
          } else if (matchingWords.any(
            (range) => absoluteStart >= range.$1 && absoluteEnd <= range.$2,
          )) {
            chunkStyle = chunkStyle.copyWith(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            );
          }

          children.add(
            TextSpan(
              text: lineText.substring(segmentStart, segmentEnd),
              style: chunkStyle,
            ),
          );
        }

        lastOffset = endOffset;
      }

      // إضافة المتبقي من السطر إن وجد
      if (lastOffset < lineText.length) {
        children.add(
          TextSpan(
            text: lineText.substring(lastOffset),
            style: theme.getStyle(0, 0),
          ),
        );
      }

      // إضافة فاصل السطر الجديد ما لم نكن في آخر سطر
      if (lineIndex < lines.length - 1) {
        children.add(const TextSpan(text: '\n'));
        absoluteLineStart += lineText.length + 1;
      }
    }

    return TextSpan(style: style, children: children);
  }
}
