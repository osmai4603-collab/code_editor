import '../contracts/configuration_scope.dart';
import '../contracts/setting_value_type.dart';

class SettingDefinition<T> {
  final String key;
  final SettingValueType type;
  final T? defaultValue;
  final String title;
  final String description;
  final List<String> tags;
  final String category;
  final int order;
  final List<SettingOption> options;
  final ConfigurationScope scope;

  SettingDefinition({
    required this.key,
    required this.type,
    required this.defaultValue,
    required this.title,
    this.description = '',
    List<String> tags = const [],
    this.category = 'Commonly Used',
    this.order = 0,
    List<SettingOption> options = const [],
    this.scope = ConfigurationScope.window,
  }) : tags = List.unmodifiable(tags),
       options = List.unmodifiable(options) {
    if (key.trim().isEmpty || !key.contains('.')) {
      throw ArgumentError.value(key, 'key', 'Must be a qualified setting key');
    }
    if (type == SettingValueType.enumeration && options.isEmpty) {
      throw ArgumentError('Enumeration settings require options');
    }
  }
}

class SettingOption {
  final String value;
  final String label;
  final String description;

  const SettingOption({
    required this.value,
    required this.label,
    this.description = '',
  });
}
