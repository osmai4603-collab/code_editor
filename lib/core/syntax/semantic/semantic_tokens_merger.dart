import 'dart:typed_data';
import '../../lsp/protocol/lsp_semantic_tokens_types.dart';
import '../model/encoded_token_attributes.dart';
import '../model/line_tokens.dart';
import 'semantic_token_styling.dart';

/// محرك دمج الرموز النحوية مع الرموز الدلالية بالعمليات البتية (Bitmask Merging)
abstract final class SemanticTokensMerger {
  /// دمج الرموز النحوية (Contiguous) مع الرموز الدلالية (Sparse) للسطر
  static LineTokens merge(LineTokens syntactic, List<DecodedSemanticToken>? semantic) {
    if (semantic == null || semantic.isEmpty || syntactic.lineLength == 0) {
      return syntactic;
    }

    final lineLength = syntactic.lineLength;
    final aLen = syntactic.count;
    final bLen = semantic.length;

    final result = <int>[];
    int lastEndOffset = 0;

    void emitToken(int endOffset, int metadata) {
      final clampedEnd = endOffset.clamp(0, lineLength);
      if (clampedEnd <= lastEndOffset) return;
      lastEndOffset = clampedEnd;
      result.add(clampedEnd);
      result.add(metadata);
    }

    int aIndex = 0;

    for (int bIndex = 0; bIndex < bLen; bIndex++) {
      final b = semantic[bIndex];
      final bStart = b.startChar.clamp(0, lineLength);
      final bEnd = b.endChar.clamp(0, lineLength);
      if (bStart >= bEnd) continue;

      final bMeta = SemanticTokenStyling.buildSemanticMetadata(
        b.tokenType,
        b.tokenModifiers,
      );

      // استخراج قناع الخصائص التي قرر الرمز الدلالي تعديلها
      int bMask = 0;
      if ((bMeta & MetadataConsts.semanticUseItalic) != 0) {
        bMask |= MetadataConsts.italicMask;
      }
      if ((bMeta & MetadataConsts.semanticUseBold) != 0) {
        bMask |= MetadataConsts.boldMask;
      }
      if ((bMeta & MetadataConsts.semanticUseUnderline) != 0) {
        bMask |= MetadataConsts.underlineMask;
      }
      if ((bMeta & MetadataConsts.semanticUseStrikethrough) != 0) {
        bMask |= MetadataConsts.strikethroughMask;
      }
      if ((bMeta & MetadataConsts.semanticUseForeground) != 0) {
        bMask |= MetadataConsts.foregroundMask;
      }
      if ((bMeta & MetadataConsts.semanticUseBackground) != 0) {
        bMask |= MetadataConsts.backgroundMask;
      }

      final aMask = ~bMask;

      // 1. إضافة أي رموز نحوية تسبق بداية الرمز الدلالي
      while (aIndex < aLen && syntactic.getEndOffset(aIndex) <= bStart) {
        emitToken(syntactic.getEndOffset(aIndex), syntactic.getMetadata(aIndex));
        aIndex++;
      }

      // 2. إذا كان الرمز النحوي يتقاطع مع بداية الرمز الدلالي، نقسم الجزء السابق
      if (aIndex < aLen && syntactic.getStartOffset(aIndex) < bStart) {
        emitToken(bStart, syntactic.getMetadata(aIndex));
      }

      // 3. تخطي ودمج أي أجزاء من الرموز النحوية تقع بالكامل داخل الرمز الدلالي
      while (aIndex < aLen && syntactic.getEndOffset(aIndex) < bEnd) {
        final aMeta = syntactic.getMetadata(aIndex);
        final mergedMeta = (aMeta & aMask) | (bMeta & bMask);
        emitToken(syntactic.getEndOffset(aIndex), mergedMeta);
        aIndex++;
      }

      // 4. دمج نهاية الرمز الدلالي
      if (aIndex < aLen) {
        final aMeta = syntactic.getMetadata(aIndex);
        final mergedMeta = (aMeta & aMask) | (bMeta & bMask);
        emitToken(bEnd, mergedMeta);
        if (syntactic.getEndOffset(aIndex) == bEnd) {
          aIndex++;
        }
      } else {
        final lastAMeta = aLen > 0 ? syntactic.getMetadata(aLen - 1) : 0;
        final mergedMeta = (lastAMeta & aMask) | (bMeta & bMask);
        emitToken(bEnd, mergedMeta);
      }
    }

    // 5. إضافة بقية الرموز النحوية المتبقية بعد نهاية آخر رمز دلالي
    while (aIndex < aLen) {
      emitToken(syntactic.getEndOffset(aIndex), syntactic.getMetadata(aIndex));
      aIndex++;
    }

    return LineTokens(
      binaryTokens: Int32List.fromList(result),
      lineLength: lineLength,
    );
  }
}
