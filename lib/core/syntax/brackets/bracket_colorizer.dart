import 'dart:typed_data';
import '../model/line_tokens.dart';
import '../model/token_metadata.dart';
import '../theme/token_color_palette.dart';

/// تمثيل حالة مكدس الأقواس عند نهاية السطر لربط الأقواس عبر الأسطر المتعددة
class BracketStackState {
  static const empty = BracketStackState([]);

  final List<int> levels; // مستويات الأقواس المفتوحة حالياً

  const BracketStackState(this.levels);

  BracketStackState copy() => BracketStackState(List.of(levels));
}

/// نتيجة تلوين الأقواس للسطر الواحد
class BracketColorizeResult {
  final LineTokens tokens;
  final BracketStackState endState;

  const BracketColorizeResult({
    required this.tokens,
    required this.endState,
  });
}

/// محرك تلوين أزواج الأقواس المتداخلة (Bracket Pair Colorizer)
abstract final class BracketColorizer {
  /// ألوان المستويات الثلاثة الأساسية المتكررة
  static int getColorIdForNestingLevel(int level) {
    final mod = (level - 1) % 3;
    return switch (mod) {
      0 => StandardColorId.bracketLevel1, // Gold
      1 => StandardColorId.bracketLevel2, // Orchid
      _ => StandardColorId.bracketLevel3, // Sky Blue
    };
  }

  /// فحص السطر وتلوين الأقواس المتوازنة دورياً
  static BracketColorizeResult colorizeLine(
    String lineText,
    LineTokens inputTokens,
    BracketStackState initialState,
  ) {
    if (inputTokens.count == 0 || lineText.isEmpty) {
      return BracketColorizeResult(
        tokens: inputTokens,
        endState: initialState,
      );
    }

    final stack = List<int>.of(initialState.levels);
    final count = inputTokens.count;
    final newBinary = Int32List.fromList(inputTokens.binaryTokens);

    for (int i = 0; i < count; i++) {
      final meta = newBinary[i * 2 + 1];
      if (!TokenMetadata.isBalancedBracket(meta)) continue;

      final startOffset = inputTokens.getStartOffset(i);
      final endOffset = inputTokens.getEndOffset(i);
      if (startOffset >= endOffset || startOffset >= lineText.length) continue;

      final ch = lineText.codeUnitAt(startOffset);

      // 1. أقواس الفتح: ( [ {
      if (ch == 40 || ch == 91 || ch == 123) {
        final currentLevel = stack.length + 1;
        stack.add(currentLevel);
        final bracketColor = getColorIdForNestingLevel(currentLevel);

        newBinary[i * 2 + 1] = TokenMetadata.encode(
          languageId: TokenMetadata.getLanguageId(meta),
          tokenType: TokenMetadata.getTokenType(meta),
          fontStyle: TokenMetadata.getFontStyle(meta),
          foreground: bracketColor,
          isBalancedBracket: true,
        );
      }
      // 2. أقواس الإغلاق: ) ] }
      else if (ch == 41 || ch == 93 || ch == 125) {
        final currentLevel = stack.isNotEmpty ? stack.removeLast() : 1;
        final bracketColor = getColorIdForNestingLevel(currentLevel);

        newBinary[i * 2 + 1] = TokenMetadata.encode(
          languageId: TokenMetadata.getLanguageId(meta),
          tokenType: TokenMetadata.getTokenType(meta),
          fontStyle: TokenMetadata.getFontStyle(meta),
          foreground: bracketColor,
          isBalancedBracket: true,
        );
      }
    }

    return BracketColorizeResult(
      tokens: LineTokens(binaryTokens: newBinary, lineLength: inputTokens.lineLength),
      endState: BracketStackState(stack),
    );
  }
}
