import 'setting_definition.dart';

class ConfigurationRegistry {
  final Map<String, SettingDefinition<Object?>> _definitions = {};

  Iterable<SettingDefinition<Object?>> get definitions =>
      List.unmodifiable(_definitions.values);

  void register<T>(SettingDefinition<T> definition) {
    if (_definitions.containsKey(definition.key)) {
      throw ArgumentError.value(
        definition.key,
        'definition.key',
        'A setting with this key is already registered',
      );
    }
    _definitions[definition.key] = SettingDefinition<Object?>(
      key: definition.key,
      type: definition.type,
      defaultValue: definition.defaultValue,
      title: definition.title,
      description: definition.description,
      tags: definition.tags,
      category: definition.category,
      order: definition.order,
      options: definition.options,
      scope: definition.scope,
    );
  }

  SettingDefinition<Object?> operator [](String key) {
    final definition = _definitions[key];
    if (definition == null) {
      throw ArgumentError.value(key, 'key', 'Unknown configuration setting');
    }
    return definition;
  }

  SettingDefinition<Object?>? find(String key) => _definitions[key];

  List<SettingDefinition<Object?>> inCategory(String category) =>
      definitions.where((setting) => setting.category == category).toList()
        ..sort((first, second) => first.order.compareTo(second.order));
}
