import 'configuration_target.dart';

class ConfigurationInspectResult<T> {
  final String key;
  final T effectiveValue;
  final T? defaultValue;
  final T? userValue;
  final T? workspaceValue;
  final bool isConfiguredInSelectedTarget;
  final bool isModified;
  final ConfigurationTarget currentTarget;

  const ConfigurationInspectResult({
    required this.key,
    required this.effectiveValue,
    required this.defaultValue,
    required this.userValue,
    required this.workspaceValue,
    required this.isConfiguredInSelectedTarget,
    required this.isModified,
    required this.currentTarget,
  });
}
