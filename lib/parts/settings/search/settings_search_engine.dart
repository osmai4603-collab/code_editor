import '../../../core/configuration/contracts/configuration_inspect_result.dart';
import '../../../core/configuration/registry/setting_definition.dart';

class SettingSearchResult {
  final SettingDefinition<Object?> setting;
  final int score;

  const SettingSearchResult(this.setting, this.score);
}

class SettingsSearchEngine {
  List<SettingSearchResult> search(
    Iterable<SettingDefinition<Object?>> settings,
    String query, {
    required ConfigurationInspectResult<Object?> Function(String key) inspect,
  }) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final ordinaryTerms = <String>[];
    var modifiedOnly = false;
    String? requiredTag;
    String? requiredId;
    for (final token in tokens) {
      if (token == '@modified') {
        modifiedOnly = true;
      } else if (token.startsWith('@tag:')) {
        requiredTag = token.substring(5).toLowerCase();
      } else if (token.startsWith('@id:')) {
        requiredId = token.substring(4).toLowerCase();
      } else if (token.startsWith('@')) {
        continue;
      } else {
        ordinaryTerms.add(token.toLowerCase());
      }
    }

    final results = <SettingSearchResult>[];
    for (final setting in settings) {
      if (modifiedOnly && !inspect(setting.key).isModified) continue;
      if (requiredTag != null &&
          !setting.tags.any((tag) => tag.toLowerCase() == requiredTag)) {
        continue;
      }
      if (requiredId != null &&
          !setting.key.toLowerCase().contains(requiredId)) {
        continue;
      }
      var score = 0;
      var matches = true;
      for (final term in ordinaryTerms) {
        final termScore = _score(setting, term);
        if (termScore == 0) {
          matches = false;
          break;
        }
        score += termScore;
      }
      if (matches) results.add(SettingSearchResult(setting, score));
    }
    results.sort((first, second) {
      final scoreOrder = second.score.compareTo(first.score);
      return scoreOrder != 0
          ? scoreOrder
          : first.setting.key.compareTo(second.setting.key);
    });
    return results;
  }

  int _score(SettingDefinition<Object?> setting, String term) {
    final key = setting.key.toLowerCase();
    if (key == term) return 100;
    if (key.startsWith(term) ||
        key.split('.').any((part) => part.startsWith(term))) {
      return 75;
    }
    if (setting.title.toLowerCase().contains(term)) return 50;
    final options = setting.options
        .map((option) => '${option.label} ${option.description}')
        .join(' ');
    if (setting.description.toLowerCase().contains(term) ||
        options.toLowerCase().contains(term)) {
      return 25;
    }
    return 0;
  }
}
