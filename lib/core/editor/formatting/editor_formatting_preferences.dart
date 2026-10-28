import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class EditorFormattingPreferences {
  final bool formatOnSave;
  final bool formatOnType;
  final bool formatOnPaste;

  const EditorFormattingPreferences({
    this.formatOnSave = false,
    this.formatOnType = false,
    this.formatOnPaste = false,
  });

  EditorFormattingPreferences copyWith({
    bool? formatOnSave,
    bool? formatOnType,
    bool? formatOnPaste,
  }) => EditorFormattingPreferences(
    formatOnSave: formatOnSave ?? this.formatOnSave,
    formatOnType: formatOnType ?? this.formatOnType,
    formatOnPaste: formatOnPaste ?? this.formatOnPaste,
  );

  Map<String, Object> toJson() => {
    'formatOnSave': formatOnSave,
    'formatOnType': formatOnType,
    'formatOnPaste': formatOnPaste,
  };

  factory EditorFormattingPreferences.fromJson(Map<String, dynamic> json) {
    bool readBool(String key) {
      final value = json[key];
      if (value == null) return false;
      if (value is! bool) {
        throw FormatException('Invalid editor formatting preference: $key');
      }
      return value;
    }

    return EditorFormattingPreferences(
      formatOnSave: readBool('formatOnSave'),
      formatOnType: readBool('formatOnType'),
      formatOnPaste: readBool('formatOnPaste'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditorFormattingPreferences &&
      formatOnSave == other.formatOnSave &&
      formatOnType == other.formatOnType &&
      formatOnPaste == other.formatOnPaste;

  @override
  int get hashCode => Object.hash(formatOnSave, formatOnType, formatOnPaste);
}

abstract interface class EditorFormattingPreferencesStore {
  Future<EditorFormattingPreferences> read();

  Future<void> write(EditorFormattingPreferences preferences);
}

class SharedPreferencesEditorFormattingPreferencesStore
    implements EditorFormattingPreferencesStore {
  static const _preferencesKey = 'editor.formatting_preferences';

  @override
  Future<EditorFormattingPreferences> read() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.get(_preferencesKey);
    if (value == null) return const EditorFormattingPreferences();
    if (value is! String) {
      throw const FormatException('Invalid editor formatting preferences');
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid editor formatting preferences');
    }
    return EditorFormattingPreferences.fromJson(decoded);
  }

  @override
  Future<void> write(EditorFormattingPreferences preferences) async {
    final store = await SharedPreferences.getInstance();
    final saved = await store.setString(
      _preferencesKey,
      jsonEncode(preferences.toJson()),
    );
    if (!saved) {
      throw StateError('Unable to save editor formatting preferences');
    }
  }
}

class InMemoryEditorFormattingPreferencesStore
    implements EditorFormattingPreferencesStore {
  EditorFormattingPreferences _preferences;

  InMemoryEditorFormattingPreferencesStore({
    EditorFormattingPreferences preferences =
        const EditorFormattingPreferences(),
  }) : _preferences = preferences;

  @override
  Future<EditorFormattingPreferences> read() async => _preferences;

  @override
  Future<void> write(EditorFormattingPreferences preferences) async {
    _preferences = preferences;
  }
}

class EditorFormattingPreferencesController extends ChangeNotifier {
  final EditorFormattingPreferencesStore _store;
  EditorFormattingPreferences _preferences =
      const EditorFormattingPreferences();
  EditorFormattingPreferences _persistedPreferences =
      const EditorFormattingPreferences();
  Future<void> _writeQueue = Future<void>.value();
  bool _isDisposed = false;

  EditorFormattingPreferencesController({
    required EditorFormattingPreferencesStore store,
  }) : _store = store;

  EditorFormattingPreferences get preferences => _preferences;

  Future<void> initialize() async {
    try {
      _preferences = await _store.read();
      _persistedPreferences = _preferences;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'editor formatting',
          context: ErrorDescription('while reading saved formatting settings'),
        ),
      );
    }
  }

  Future<void> update(EditorFormattingPreferences preferences) {
    if (_isDisposed) {
      throw StateError('Editor formatting preferences are disposed');
    }
    if (_preferences == preferences) return Future<void>.value();

    _preferences = preferences;
    notifyListeners();
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _store.write(preferences);
        _persistedPreferences = preferences;
        completer.complete();
      } catch (error, stackTrace) {
        if (!_isDisposed && _preferences == preferences) {
          _preferences = _persistedPreferences;
          notifyListeners();
        }
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
