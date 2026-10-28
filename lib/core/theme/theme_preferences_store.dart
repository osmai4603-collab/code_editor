import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemePreferencesStore {
  Future<String?> readThemeId();

  Future<void> writeThemeId(String themeId);
}

class SharedPreferencesThemePreferencesStore implements ThemePreferencesStore {
  static const _themeIdKey = 'appearance.color_theme';

  @override
  Future<String?> readThemeId() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.get(_themeIdKey);
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    throw const FormatException('Invalid saved color theme preference');
  }

  @override
  Future<void> writeThemeId(String themeId) async {
    if (themeId.isEmpty) {
      throw ArgumentError.value(themeId, 'themeId', 'Must not be empty');
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_themeIdKey, themeId);
    if (!saved) {
      throw StateError('Unable to save color theme preference');
    }
  }
}

class InMemoryThemePreferencesStore implements ThemePreferencesStore {
  String? _themeId;

  InMemoryThemePreferencesStore({String? themeId}) : _themeId = themeId;

  @override
  Future<String?> readThemeId() async => _themeId;

  @override
  Future<void> writeThemeId(String themeId) async {
    if (themeId.isEmpty) {
      throw ArgumentError.value(themeId, 'themeId', 'Must not be empty');
    }
    _themeId = themeId;
  }
}
