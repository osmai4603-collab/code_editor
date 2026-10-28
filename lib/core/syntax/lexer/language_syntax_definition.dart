/// تعريف قواعد نحو لغة برمجية بشكل مجرد وغير مرتبط بأي مكتبة خارجية
class LanguageSyntaxDefinition {
  final String languageId;
  final List<String> extensions;

  // الكلمات المفتاحية
  final Set<String> keywords;
  final Set<String> controlKeywords;
  final Set<String> typeKeywords;
  final Set<String> constantKeywords;

  // التعليقات
  final String? lineCommentPrefix;
  final String? docCommentPrefix;
  final String? blockCommentStart;
  final String? blockCommentEnd;

  // الأقواس والمعاملات
  final Set<int> bracketCharacters; // كرموز ASCII للأقواس () [] {}
  final Set<int> operatorCharacters;

  const LanguageSyntaxDefinition({
    required this.languageId,
    required this.extensions,
    this.keywords = const {},
    this.controlKeywords = const {},
    this.typeKeywords = const {},
    this.constantKeywords = const {},
    this.lineCommentPrefix,
    this.docCommentPrefix,
    this.blockCommentStart,
    this.blockCommentEnd,
    this.bracketCharacters = const {40, 41, 91, 93, 123, 125}, // ( ) [ ] { }
    this.operatorCharacters = const {
      43, 45, 42, 47, 37, 61, 33, 60, 62, 38, 124, 94, 126, 63, 58
    }, // + - * / % = ! < > & | ^ ~ ? :
  });
}
