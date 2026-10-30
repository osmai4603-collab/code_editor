import 'dart:async';

import 'package:flutter/foundation.dart';

import '../contracts/configuration_inspect_result.dart';
import '../contracts/configuration_service.dart';
import '../contracts/configuration_target.dart';
import '../contracts/setting_value_type.dart';
import '../registry/configuration_registry.dart';
import '../stores/configuration_store.dart';

class ConfigurationService extends ChangeNotifier
    implements IConfigurationService {
  final ConfigurationRegistry registry;
  final IConfigurationStore userStore;
  final IConfigurationStore workspaceStore;
  final IConfigurationStore memoryStore;
  final StreamController<ConfigurationChangeEvent> _changes =
      StreamController.broadcast();
  Map<String, Object?> _userValues = {};
  Map<String, Object?> _workspaceValues = {};
  Map<String, Object?> _memoryValues = {};
  Future<void> _writeQueue = Future<void>.value();
  bool _isDisposed = false;

  ConfigurationService({
    required this.registry,
    required this.userStore,
    required this.workspaceStore,
    required this.memoryStore,
  });

  @override
  Stream<ConfigurationChangeEvent> get onDidChangeConfiguration =>
      _changes.stream;

  Future<void> initialize() async {
    final values = await Future.wait([
      userStore.readAll(),
      workspaceStore.readAll(),
      memoryStore.readAll(),
    ]);
    _userValues = values[0];
    _workspaceValues = values[1];
    _memoryValues = values[2];
  }

  Future<void> reloadWorkspace() async {
    _workspaceValues = await workspaceStore.readAll();
    if (!_isDisposed) {
      _changes.add(
        ConfigurationChangeEvent(
          changedKeys: registry.definitions.map((setting) => setting.key),
          target: ConfigurationTarget.workspace,
        ),
      );
      notifyListeners();
    }
  }

  @override
  T getValue<T>(String key) {
    final definition = registry[key];
    final value = _effectiveValue(key, definition.defaultValue);
    if (value is! T) {
      throw StateError('Configuration "$key" does not contain a $T value');
    }
    return value;
  }

  @override
  ConfigurationInspectResult<T> inspect<T>(
    String key, {
    ConfigurationTarget target = ConfigurationTarget.user,
  }) {
    final definition = registry[key];
    final defaultValue = definition.defaultValue;
    final userValue = _userValues[key];
    final workspaceValue = _workspaceValues[key];
    final effectiveValue = _effectiveValue(key, defaultValue);
    if (effectiveValue != null && effectiveValue is! T) {
      throw StateError('Configuration "$key" does not contain a $T value');
    }
    return ConfigurationInspectResult<T>(
      key: key,
      effectiveValue: effectiveValue as T,
      defaultValue: defaultValue as T?,
      userValue: userValue as T?,
      workspaceValue: workspaceValue as T?,
      isConfiguredInSelectedTarget: _valuesFor(target).containsKey(key),
      isModified:
          !_sameValue(effectiveValue, defaultValue) ||
          (userValue != null && !_sameValue(userValue, defaultValue)) ||
          (workspaceValue != null && !_sameValue(workspaceValue, defaultValue)),
      currentTarget: target,
    );
  }

  Object? _effectiveValue(String key, Object? defaultValue) =>
      _memoryValues.containsKey(key)
      ? _memoryValues[key]
      : _workspaceValues.containsKey(key)
      ? _workspaceValues[key]
      : _userValues.containsKey(key)
      ? _userValues[key]
      : defaultValue;

  Map<String, Object?> _valuesFor(ConfigurationTarget target) =>
      switch (target) {
        ConfigurationTarget.user => _userValues,
        ConfigurationTarget.workspace => _workspaceValues,
        ConfigurationTarget.memory => _memoryValues,
      };

  IConfigurationStore _storeFor(ConfigurationTarget target) => switch (target) {
    ConfigurationTarget.user => userStore,
    ConfigurationTarget.workspace => workspaceStore,
    ConfigurationTarget.memory => memoryStore,
  };

  @override
  Future<void> updateValue(
    String key,
    Object? value, {
    ConfigurationTarget target = ConfigurationTarget.user,
  }) {
    final definition = registry[key];
    if (value != null && !_matchesType(definition.type, value)) {
      throw ArgumentError.value(
        value,
        'value',
        'Invalid value type for configuration "$key"',
      );
    }
    if (value != null &&
        definition.type == SettingValueType.enumeration &&
        !definition.options.any((option) => option.value == value)) {
      throw ArgumentError.value(value, 'value', 'Unknown option for "$key"');
    }
    if (_sameValue(value, definition.defaultValue)) {
      return resetValue(key, target: target);
    }
    final values = _valuesFor(target);
    if (_sameValue(values[key], value) && values.containsKey(key)) {
      return Future<void>.value();
    }
    final oldEffective = _effectiveValue(key, definition.defaultValue);
    final oldStored = values[key];
    final hadStoredValue = values.containsKey(key);
    values[key] = value;
    final newEffective = _effectiveValue(key, definition.defaultValue);
    if (!_sameValue(oldEffective, newEffective)) _publishChange(key, target);
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storeFor(target).write(key, value);
        completer.complete();
      } catch (error, stackTrace) {
        if (_sameValue(values[key], value)) {
          if (hadStoredValue) {
            values[key] = oldStored;
          } else {
            values.remove(key);
          }
          if (!_sameValue(oldEffective, newEffective)) {
            _publishChange(key, target);
          }
        }
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<void> resetValue(
    String key, {
    ConfigurationTarget target = ConfigurationTarget.user,
  }) {
    final definition = registry[key];
    final values = _valuesFor(target);
    if (!values.containsKey(key)) return Future<void>.value();
    final oldValue = values.remove(key);
    final newEffective = _effectiveValue(key, definition.defaultValue);
    if (!_sameValue(oldValue, newEffective)) _publishChange(key, target);
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storeFor(target).remove(key);
        completer.complete();
      } catch (error, stackTrace) {
        if (!values.containsKey(key)) {
          values[key] = oldValue;
          _publishChange(key, target);
        }
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  bool _matchesType(SettingValueType type, Object value) => switch (type) {
    SettingValueType.boolean => value is bool,
    SettingValueType.string ||
    SettingValueType.multilineString ||
    SettingValueType.enumeration => value is String,
    SettingValueType.integer => value is int,
    SettingValueType.doubleNumber => value is double || value is int,
    SettingValueType.stringList =>
      value is List && value.every((item) => item is String),
    SettingValueType.stringMap || SettingValueType.excludePatterns =>
      value is Map &&
          value.keys.every((key) => key is String) &&
          value.values.every(
            (item) => item is String || item is bool || item is num,
          ),
    SettingValueType.complex => value is Map || value is List,
  };

  bool _sameValue(Object? first, Object? second) {
    if (identical(first, second) || first == second) return true;
    if (first is List && second is List) {
      if (first.length != second.length) return false;
      for (var index = 0; index < first.length; index++) {
        if (!_sameValue(first[index], second[index])) return false;
      }
      return true;
    }
    if (first is Map && second is Map) {
      if (first.length != second.length) return false;
      for (final key in first.keys) {
        if (!second.containsKey(key) || !_sameValue(first[key], second[key])) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  void _publishChange(String key, ConfigurationTarget target) {
    final event = ConfigurationChangeEvent(changedKeys: [key], target: target);
    if (!_isDisposed) {
      _changes.add(event);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _changes.close();
    super.dispose();
  }
}
