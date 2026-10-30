import 'configuration_inspect_result.dart';
import 'configuration_target.dart';

abstract interface class IConfigurationReader {
  T getValue<T>(String key);

  ConfigurationInspectResult<T> inspect<T>(
    String key, {
    ConfigurationTarget target = ConfigurationTarget.user,
  });
}

abstract interface class IConfigurationWriter {
  Future<void> updateValue(
    String key,
    Object? value, {
    ConfigurationTarget target = ConfigurationTarget.user,
  });

  Future<void> resetValue(
    String key, {
    ConfigurationTarget target = ConfigurationTarget.user,
  });
}

abstract interface class IConfigurationInspector {
  Stream<ConfigurationChangeEvent> get onDidChangeConfiguration;
}

abstract interface class IConfigurationService
    implements
        IConfigurationReader,
        IConfigurationWriter,
        IConfigurationInspector {}

class ConfigurationChangeEvent {
  final Set<String> changedKeys;
  final ConfigurationTarget target;

  ConfigurationChangeEvent({
    required Iterable<String> changedKeys,
    required this.target,
  }) : changedKeys = Set.unmodifiable(changedKeys);

  bool affects(String key) => changedKeys.contains(key);
}
