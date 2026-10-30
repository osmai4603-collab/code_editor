class LanguageFeatureScore {
  const LanguageFeatureScore._();

  static int forDocument({
    required String languageId,
    required String uri,
    required Set<String> languageIds,
    String? uriPattern,
  }) {
    if (languageIds.isNotEmpty &&
        !languageIds.contains('*') &&
        !languageIds.contains(languageId)) {
      return 0;
    }

    if (uriPattern == null || uriPattern == '*') {
      return languageIds.contains(languageId) ? 2 : 1;
    }
    if (_matchesUriPattern(uri, uriPattern)) return 3;
    return 0;
  }

  static bool _matchesUriPattern(String uri, String pattern) {
    final escaped = RegExp.escape(pattern).replaceAll(r'\*', '.*');
    return RegExp('^$escaped\$').hasMatch(uri);
  }
}
