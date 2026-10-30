/// Language-specific indentation and auto-closing behavior.
abstract interface class LanguageIndentationRules {
  bool shouldIndentAfterLine(String lineText);

  bool shouldOutdentLine(String lineText);

  int calculateIndentIncrement(String previousLine);

  List<String> get autoClosePairs;
}

/// Rules that indent after opening brackets.
class BracketIndentationRules implements LanguageIndentationRules {
  const BracketIndentationRules();

  @override
  bool shouldIndentAfterLine(String lineText) =>
      const ['{', '[', '('].contains(_lastNonWhitespace(lineText));

  @override
  bool shouldOutdentLine(String lineText) => false;

  @override
  int calculateIndentIncrement(String previousLine) =>
      shouldIndentAfterLine(previousLine) ? 1 : 0;

  @override
  List<String> get autoClosePairs => const [
    '()',
    '[]',
    '{}',
    '""',
    "''",
    '``',
  ];
}

/// Rules for Python suite headers and delimiters.
class PythonIndentationRules extends BracketIndentationRules {
  const PythonIndentationRules();

  @override
  bool shouldIndentAfterLine(String lineText) =>
      super.shouldIndentAfterLine(lineText) ||
      lineText.trimRight().endsWith(':');
}

String _lastNonWhitespace(String value) {
  for (var index = value.length - 1; index >= 0; index--) {
    if (value[index].trim().isNotEmpty) return value[index];
  }
  return '';
}
