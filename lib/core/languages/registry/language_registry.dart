import 'dart:collection';

import '../models/language_definition.dart';

/// Registers and resolves language definitions by ID, filename, or extension.
class LanguageRegistry {
  final Map<String, LanguageDefinition> _definitions = {};

  LanguageRegistry([Iterable<LanguageDefinition> definitions = const []]) {
    for (final definition in definitions) {
      register(definition);
    }
  }

  UnmodifiableListView<LanguageDefinition> get definitions =>
      UnmodifiableListView(_definitions.values.toList());

  void register(LanguageDefinition definition) {
    final id = definition.id.toLowerCase();
    if (id.isEmpty) throw ArgumentError.value(definition.id, 'id');
    _definitions[id] = definition;
  }

  LanguageDefinition? byId(String id) => _definitions[id.toLowerCase()];

  LanguageDefinition? forPath(String path) {
    final filenameMatches = _definitions.values.where(
      (definition) => definition.filenames.any(
        (filename) =>
            filename.toLowerCase() ==
            path.split(RegExp(r'[/\\]')).last.toLowerCase(),
      ),
    );
    if (filenameMatches.isNotEmpty) return filenameMatches.first;
    for (final definition in _definitions.values) {
      if (definition.matchesPath(path)) return definition;
    }
    return null;
  }

  String resolveLanguageId(String path) => forPath(path)?.id ?? 'plaintext';
}
