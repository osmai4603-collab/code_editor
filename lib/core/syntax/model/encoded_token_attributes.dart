/// أنماط الخط المدعومة كأقنعة بتية (2^x)
abstract final class FontStyleMask {
  static const int none = 0;
  static const int italic = 1; // 0b0001
  static const int bold = 2; // 0b0010
  static const int underline = 4; // 0b0100
  static const int strikethrough = 8; // 0b1000
}

/// الأنواع المعيارية العامة للرموز النحوية (2 بت: 0..3)
enum StandardTokenType {
  other(0),
  comment(1),
  string(2),
  regex(3);

  final int value;
  const StandardTokenType(this.value);

  static StandardTokenType fromValue(int val) {
    return switch (val) {
      1 => StandardTokenType.comment,
      2 => StandardTokenType.string,
      3 => StandardTokenType.regex,
      _ => StandardTokenType.other,
    };
  }
}

/// ثوابت الأقنعة البتية والإزاحات للرقم الثنائي 32-bit Token Metadata
///
/// تمثيل البيانات داخل 32 بت:
/// -------------------------------------------
/// 3322 2222 2222 1111 1111 1100 0000 0000
/// 1098 7654 3210 9876 5432 1098 7654 3210
/// -------------------------------------------
/// bbbb bbbb ffff ffff fFFF FBTT LLLL LLLL
/// -------------------------------------------
/// L = LanguageId (8 bits: 0..255)
/// T = StandardTokenType (2 bits: 0..3)
/// B = Balanced Bracket (1 bit)
/// F = FontStyle (4 bits: Italic, Bold, Underline, Strikethrough)
/// f = Foreground ColorId (9 bits: 0..511)
/// b = Background ColorId (8 bits: 0..255)
abstract final class MetadataConsts {
  // الأقنعة
  static const int languageIdMask = 0x000000FF;
  static const int tokenTypeMask = 0x00000300;
  static const int balancedBracketMask = 0x00000400;
  static const int fontStyleMask = 0x00007800;
  static const int foregroundMask = 0x00FF8000;
  static const int backgroundMask = 0xFF000000;

  // أقنعة أنماط الخط الفردية
  static const int italicMask = 0x00000800;
  static const int boldMask = 0x00001000;
  static const int underlineMask = 0x00002000;
  static const int strikethroughMask = 0x00004000;

  // بتات التحكم الدلالية (Semantic Control Bits)
  static const int semanticUseItalic = 0x01;
  static const int semanticUseBold = 0x02;
  static const int semanticUseUnderline = 0x04;
  static const int semanticUseStrikethrough = 0x08;
  static const int semanticUseForeground = 0x10;
  static const int semanticUseBackground = 0x20;

  // الإزاحات البتية (Offsets)
  static const int languageIdOffset = 0;
  static const int tokenTypeOffset = 8;
  static const int balancedBracketOffset = 10;
  static const int fontStyleOffset = 11;
  static const int foregroundOffset = 15;
  static const int backgroundOffset = 24;
}
