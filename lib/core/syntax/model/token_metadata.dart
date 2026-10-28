import 'encoded_token_attributes.dart';

/// دوال مساعدة استاتيكية لتشفير وفك تشفير خصائص الرمز من العدد الصحيح 32-bit
abstract final class TokenMetadata {
  /// تركيب وتوليد عدد صحيح 32-bit يدمج كافة خصائص الرمز
  static int encode({
    int languageId = 0,
    StandardTokenType tokenType = StandardTokenType.other,
    bool isBalancedBracket = false,
    int fontStyle = FontStyleMask.none,
    int foreground = 0,
    int background = 0,
  }) {
    return ((languageId & 0xFF) << MetadataConsts.languageIdOffset) |
        ((tokenType.value & 0x03) << MetadataConsts.tokenTypeOffset) |
        ((isBalancedBracket ? 1 : 0) << MetadataConsts.balancedBracketOffset) |
        ((fontStyle & 0x0F) << MetadataConsts.fontStyleOffset) |
        ((foreground & 0x1FF) << MetadataConsts.foregroundOffset) |
        ((background & 0xFF) << MetadataConsts.backgroundOffset);
  }

  /// استخراج معرّف اللغة (0..255)
  static int getLanguageId(int metadata) {
    return (metadata & MetadataConsts.languageIdMask) >>>
        MetadataConsts.languageIdOffset;
  }

  /// استخراج نوع الرمز المعياري (StandardTokenType)
  static StandardTokenType getTokenType(int metadata) {
    final val = (metadata & MetadataConsts.tokenTypeMask) >>>
        MetadataConsts.tokenTypeOffset;
    return StandardTokenType.fromValue(val);
  }

  /// هل الرمز قوس متوازن
  static bool isBalancedBracket(int metadata) {
    return (metadata & MetadataConsts.balancedBracketMask) != 0;
  }

  /// استخراج قناع نمط الخط (غامق، مائل، تسطير)
  static int getFontStyle(int metadata) {
    return (metadata & MetadataConsts.fontStyleMask) >>>
        MetadataConsts.fontStyleOffset;
  }

  /// فحص هل الرمز بخط مائل
  static bool isItalic(int metadata) {
    return (metadata & MetadataConsts.italicMask) != 0;
  }

  /// فحص هل الرمز بخط عريض
  static bool isBold(int metadata) {
    return (metadata & MetadataConsts.boldMask) != 0;
  }

  /// فحص هل الرمز تحته خط
  static bool isUnderline(int metadata) {
    return (metadata & MetadataConsts.underlineMask) != 0;
  }

  /// فحص هل الرمز مشطوب
  static bool isStrikethrough(int metadata) {
    return (metadata & MetadataConsts.strikethroughMask) != 0;
  }

  /// استخراج معرّف اللون الأمامي في لوحة الألوان (0..511)
  static int getForeground(int metadata) {
    return (metadata & MetadataConsts.foregroundMask) >>>
        MetadataConsts.foregroundOffset;
  }

  /// استخراج معرّف لون الخلفية (0..255)
  static int getBackground(int metadata) {
    return (metadata & MetadataConsts.backgroundMask) >>>
        MetadataConsts.backgroundOffset;
  }
}
