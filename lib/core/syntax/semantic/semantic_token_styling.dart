import '../model/encoded_token_attributes.dart';
import '../model/token_metadata.dart';
import '../theme/token_color_palette.dart';

/// ترجمة أنواع الرموز الدلالية ومعدلاتها إلى قيم وأقنعة بتية 32-bit
class SemanticTokenStyling {
  /// تحويل نوع الرمز الدلالي إلى معرف لون `ColorId`
  static int getColorIdForTokenType(String tokenType) {
    return switch (tokenType) {
      'type' || 'class' || 'struct' || 'interface' || 'enum' || 'typeParameter' =>
        StandardColorId.type,
      'function' || 'method' || 'macro' => StandardColorId.function,
      'variable' || 'parameter' => StandardColorId.variable,
      'property' || 'enumMember' => StandardColorId.constant,
      'keyword' => StandardColorId.keyword,
      'comment' => StandardColorId.comment,
      'string' => StandardColorId.stringLiteral,
      'number' => StandardColorId.number,
      'operator' => StandardColorId.operator,
      'regexp' => StandardColorId.regex,
      _ => StandardColorId.variable,
    };
  }

  /// إنشاء قيمة metadata دلالية مع بتات التحكم التي تخبر المحرك بما يجب تعديله
  static int buildSemanticMetadata(String tokenType, int modifiers) {
    final fg = getColorIdForTokenType(tokenType);
    int fontStyle = FontStyleMask.none;
    int controlBits = MetadataConsts.semanticUseForeground;

    // فحص المعدلات: static, deprecated, async
    // modifier 2: readonly, modifier 3: static, modifier 4: deprecated
    if ((modifiers & (1 << 3)) != 0) {
      // static
      fontStyle |= FontStyleMask.italic;
      controlBits |= MetadataConsts.semanticUseItalic;
    }
    if ((modifiers & (1 << 4)) != 0) {
      // deprecated
      fontStyle |= FontStyleMask.strikethrough;
      controlBits |= MetadataConsts.semanticUseStrikethrough;
    }

    final baseMeta = TokenMetadata.encode(
      foreground: fg,
      fontStyle: fontStyle,
    );

    // إضافة بتات التحكم في أول 8 بت (مكان languageId غير المستخدم في الدلالة)
    return baseMeta | controlBits;
  }
}
