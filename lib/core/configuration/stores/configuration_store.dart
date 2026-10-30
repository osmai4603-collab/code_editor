import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class IConfigurationStore {
  Future<Map<String, Object?>> readAll();

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);
}

class InMemoryConfigurationStore implements IConfigurationStore {
  final Map<String, Object?> _values;

  InMemoryConfigurationStore([Map<String, Object?> initialValues = const {}])
    : _values = Map.of(initialValues);

  @override
  Future<Map<String, Object?>> readAll() async => Map.unmodifiable(_values);

  @override
  Future<void> write(String key, Object? value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

class SharedPreferencesConfigurationStore implements IConfigurationStore {
  final String prefix;

  const SharedPreferencesConfigurationStore({
    this.prefix = 'configuration.user.',
  });

  String get _storageKey => '${prefix}__values';

  @override
  Future<Map<String, Object?>> readAll() async {
    final preferences = await SharedPreferences.getInstance();
    final values = <String, Object?>{};
    final serialized = preferences.get(_storageKey);
    if (serialized != null) {
      if (serialized is! String) {
        throw const FormatException('Invalid saved configuration values');
      }
      final decoded = jsonDecode(serialized);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid saved configuration values');
      }
      values.addAll(decoded);
    }
    for (final entry in preferences.getKeys()) {
      if (!entry.startsWith(prefix) || entry == _storageKey) continue;
      final value = preferences.get(entry);
      if (value is String || value is bool || value is int || value is double) {
        values[entry.substring(prefix.length)] = value;
      } else if (value is List<String>) {
        values[entry.substring(prefix.length)] = value;
      } else {
        throw FormatException('Unsupported stored configuration value: $entry');
      }
    }
    return values;
  }

  @override
  Future<void> write(String key, Object? value) async {
    final preferences = await SharedPreferences.getInstance();
    final values = await readAll();
    values[key] = value;
    final saved = await preferences.setString(_storageKey, jsonEncode(values));
    if (!saved) throw StateError('Unable to save configuration "$key"');
  }

  @override
  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final values = await readAll();
    if (!values.containsKey(key)) return;
    values.remove(key);
    final saved = await preferences.setString(_storageKey, jsonEncode(values));
    if (!saved) throw StateError('Unable to reset configuration "$key"');
  }
}

class JsonFileConfigurationStore implements IConfigurationStore {
  final File file;
  Map<String, Object?>? _cache;

  JsonFileConfigurationStore(this.file);

  Future<Map<String, Object?>> _readFile() async {
    if (_cache != null) return _cache!;
    if (!await file.exists()) return _cache = {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Workspace settings must contain a JSON object');
    }

    return _cache = Map<String, Object?>.from(decoded);
  }

  @override
  Future<Map<String, Object?>> readAll() async =>
      Map.unmodifiable(await _readFile());

  @override
  Future<void> write(String key, Object? value) async {
    final values = await _readFile();
    values[key] = value;
    await _flush(values);
  }

  @override
  Future<void> remove(String key) async {
    final values = await _readFile();
    values.remove(key);
    await _flush(values);
  }

  Future<void> _flush(Map<String, Object?> values) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(values),
      flush: true,
    );
    _cache = values;
  }
}

class WorkspaceJsonConfigurationStore implements IConfigurationStore {
  final String? Function() workspacePath;

  const WorkspaceJsonConfigurationStore(this.workspacePath);

  JsonFileConfigurationStore _store() {
    final path = workspacePath();
    if (path == null || path.isEmpty) {
      throw StateError('Open a workspace before editing workspace settings');
    }
    return JsonFileConfigurationStore(File('$path/.vscode/settings.json'));
  }

  @override
  Future<Map<String, Object?>> readAll() async {
    final path = workspacePath();
    if (path == null || path.isEmpty) return {};
    return JsonFileConfigurationStore(
      File('$path/.vscode/settings.json'),
    ).readAll();
  }

  @override
  Future<void> write(String key, Object? value) => _store().write(key, value);

  @override
  Future<void> remove(String key) => _store().remove(key);
}
