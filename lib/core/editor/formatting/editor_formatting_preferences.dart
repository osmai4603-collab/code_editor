import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FormatOnSaveMode {
  file,
  modifications,
  modificationsIfAvailable;

  static FormatOnSaveMode fromJson(Object? value) {
    if (value == null) return FormatOnSaveMode.file;
    return FormatOnSaveMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => throw const FormatException(
        'Invalid editor formatting preference: formatOnSaveMode',
      ),
    );
  }
}

@immutable
class EditorFormattingOverride {
  final bool? formatOnSave;
  final bool? formatOnType;
  final bool? formatOnPaste;
  final FormatOnSaveMode? formatOnSaveMode;
  final String? defaultFormatter;

  const EditorFormattingOverride({
    this.formatOnSave,
    this.formatOnType,
    this.formatOnPaste,
    this.formatOnSaveMode,
    this.defaultFormatter,
  });

  @override
  bool operator ==(Object other) =>
      other is EditorFormattingOverride &&
      formatOnSave == other.formatOnSave &&
      formatOnType == other.formatOnType &&
      formatOnPaste == other.formatOnPaste &&
      formatOnSaveMode == other.formatOnSaveMode &&
      defaultFormatter == other.defaultFormatter;

  @override
  int get hashCode => Object.hash(
    formatOnSave,
    formatOnType,
    formatOnPaste,
    formatOnSaveMode,
    defaultFormatter,
  );

  Map<String, Object?> toJson() => {
    if (formatOnSave != null) 'formatOnSave': formatOnSave,
    if (formatOnType != null) 'formatOnType': formatOnType,
    if (formatOnPaste != null) 'formatOnPaste': formatOnPaste,
    if (formatOnSaveMode != null)
      'formatOnSaveMode': formatOnSaveMode!.name,
    if (defaultFormatter != null) 'defaultFormatter': defaultFormatter,
  };

  factory EditorFormattingOverride.fromJson(Map<String, dynamic> json) {
    bool? readBool(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! bool) {
        throw FormatException('Invalid editor formatting preference: $key');
      }
      return value;
    }

    final formatter = json['defaultFormatter'];
    if (formatter != null && formatter is! String) {
      throw const FormatException(
        'Invalid editor formatting preference: defaultFormatter',
      );
    }

    return EditorFormattingOverride(
      formatOnSave: readBool('formatOnSave'),
      formatOnType: readBool('formatOnType'),
      formatOnPaste: readBool('formatOnPaste'),
      formatOnSaveMode: json.containsKey('formatOnSaveMode')
          ? FormatOnSaveMode.fromJson(json['formatOnSaveMode'])
          : null,
      defaultFormatter: formatter as String?,
    );
  }
}

@immutable
class EditorFormattingPreferences {
  final bool formatOnSave;
  final bool formatOnType;
  final bool formatOnPaste;
  final FormatOnSaveMode formatOnSaveMode;
  final String? defaultFormatter;
  final Map<String, EditorFormattingOverride> languageOverrides;

  const EditorFormattingPreferences({
    this.formatOnSave = false,
    this.formatOnType = false,
    this.formatOnPaste = false,
    this.formatOnSaveMode = FormatOnSaveMode.file,
    this.defaultFormatter,
    this.languageOverrides = const {},
  });

  EditorFormattingPreferences copyWith({
    bool? formatOnSave,
    bool? formatOnType,
    bool? formatOnPaste,
    FormatOnSaveMode? formatOnSaveMode,
    String? defaultFormatter,
    bool clearDefaultFormatter = false,
    Map<String, EditorFormattingOverride>? languageOverrides,
  }) => EditorFormattingPreferences(
    formatOnSave: formatOnSave ?? this.formatOnSave,
    formatOnType: formatOnType ?? this.formatOnType,
    formatOnPaste: formatOnPaste ?? this.formatOnPaste,
    formatOnSaveMode: formatOnSaveMode ?? this.formatOnSaveMode,
    defaultFormatter: clearDefaultFormatter
        ? null
        : defaultFormatter ?? this.defaultFormatter,
    languageOverrides: languageOverrides ?? this.languageOverrides,
  );

  EditorFormattingPreferences forLanguage(String languageId) {
    final override = languageOverrides[languageId];
    if (override == null) return this;
    return copyWith(
      formatOnSave: override.formatOnSave,
      formatOnType: override.formatOnType,
      formatOnPaste: override.formatOnPaste,
      formatOnSaveMode: override.formatOnSaveMode,
      defaultFormatter: override.defaultFormatter,
    );
  }

  Map<String, Object?> toJson() => {
    'formatOnSave': formatOnSave,
    'formatOnType': formatOnType,
    'formatOnPaste': formatOnPaste,
    'formatOnSaveMode': formatOnSaveMode.name,
    if (defaultFormatter != null) 'defaultFormatter': defaultFormatter,
    'languageOverrides': languageOverrides.map(
      (language, override) => MapEntry(language, override.toJson()),
    ),
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

    final formatter = json['defaultFormatter'];
    if (formatter != null && formatter is! String) {
      throw const FormatException(
        'Invalid editor formatting preference: defaultFormatter',
      );
    }
    final rawOverrides = json['languageOverrides'];
    if (rawOverrides != null && rawOverrides is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid editor formatting preference: languageOverrides',
      );
    }
    final overrides = <String, EditorFormattingOverride>{};
    for (final entry in (rawOverrides as Map<String, dynamic>? ?? {}).entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw FormatException(
          'Invalid editor formatting preference: languageOverrides.${entry.key}',
        );
      }
      overrides[entry.key] = EditorFormattingOverride.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }

    return EditorFormattingPreferences(
      formatOnSave: readBool('formatOnSave'),
      formatOnType: readBool('formatOnType'),
      formatOnPaste: readBool('formatOnPaste'),
      formatOnSaveMode: FormatOnSaveMode.fromJson(json['formatOnSaveMode']),
      defaultFormatter: formatter as String?,
      languageOverrides: Map.unmodifiable(overrides),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditorFormattingPreferences &&
      formatOnSave == other.formatOnSave &&
      formatOnType == other.formatOnType &&
      formatOnPaste == other.formatOnPaste &&
      formatOnSaveMode == other.formatOnSaveMode &&
      defaultFormatter == other.defaultFormatter &&
      mapEquals(languageOverrides, other.languageOverrides);

  @override
  int get hashCode => Object.hash(
    formatOnSave,
    formatOnType,
    formatOnPaste,
    formatOnSaveMode,
    defaultFormatter,
    Object.hashAllUnordered(
      languageOverrides.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
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
    EditorFormattingPreferences initialPreferences =
        const EditorFormattingPreferences(),
  }) : _preferences = initialPreferences;

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
    required EditorFormattingPreferencesStore preferencesStore,
  }) : _store = preferencesStore;

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
