/// توصيف خادم لغة برمجية معين (Language Server Descriptor)
///
/// يسمح بتسجيل أي خادم LSP خارجي بسهولة بمجرد تحديد الأمر والامتدادات.
class LanguageServerDescriptor {
  final String id;
  final String name;
  final String languageId;
  final List<String> fileExtensions;
  final String command;
  final List<String> args;
  final Map<String, dynamic>? initializationOptions;
  final Map<String, String>? environment;

  const LanguageServerDescriptor({
    required this.id,
    required this.name,
    required this.languageId,
    required this.fileExtensions,
    required this.command,
    this.args = const [],
    this.initializationOptions,
    this.environment,
  });

  /// فحص هل هذا الخادم يدعم ملفاً بناءً على مساره أو امتداده
  bool matches(String filePath) {
    for (final ext in fileExtensions) {
      if (filePath.endsWith(ext)) return true;
    }
    return false;
  }
}
