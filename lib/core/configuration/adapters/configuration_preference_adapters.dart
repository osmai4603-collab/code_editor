import '../../editor/formatting/editor_formatting_preferences.dart';
import '../../statusbar/status_bar_preferences_store.dart';
import '../../theme/theme_preferences_store.dart';
import '../contracts/configuration_target.dart';
import '../services/configuration_service.dart';

class ConfigurationThemePreferencesStore implements ThemePreferencesStore {
  final ConfigurationService configuration;
  final ThemePreferencesStore legacyStore;

  const ConfigurationThemePreferencesStore({
    required this.configuration,
    required this.legacyStore,
  });

  @override
  Future<String?> readThemeId() async {
    final inspected = configuration.inspect<String>(
      'workbench.colorTheme',
      target: ConfigurationTarget.user,
    );
    if (inspected.isConfiguredInSelectedTarget) return inspected.userValue;
    final legacyValue = await legacyStore.readThemeId();
    if (legacyValue != null) {
      await configuration.updateValue('workbench.colorTheme', legacyValue);
    }
    return legacyValue;
  }

  @override
  Future<void> writeThemeId(String themeId) =>
      configuration.updateValue('workbench.colorTheme', themeId);
}

class ConfigurationStatusBarPreferencesStore
    implements StatusBarPreferencesStore {
  final ConfigurationService configuration;
  final StatusBarPreferencesStore legacyStore;

  const ConfigurationStatusBarPreferencesStore({
    required this.configuration,
    required this.legacyStore,
  });

  @override
  Future<Set<String>> readHiddenEntryIds() async {
    final inspected = configuration.inspect<List<Object?>>(
      'workbench.statusBar.hiddenItems',
      target: ConfigurationTarget.user,
    );
    if (inspected.isConfiguredInSelectedTarget) {
      return (inspected.userValue ?? const <Object?>[]).cast<String>().toSet();
    }
    final legacyValue = await legacyStore.readHiddenEntryIds();
    if (legacyValue.isNotEmpty) {
      await configuration.updateValue(
        'workbench.statusBar.hiddenItems',
        legacyValue.toList()..sort(),
      );
    }
    return legacyValue;
  }

  @override
  Future<void> writeHiddenEntryIds(Set<String> ids) => configuration
      .updateValue('workbench.statusBar.hiddenItems', ids.toList()..sort());
}

class ConfigurationFormattingPreferencesStore
    implements EditorFormattingPreferencesStore {
  final ConfigurationService configuration;
  final EditorFormattingPreferencesStore legacyStore;

  const ConfigurationFormattingPreferencesStore({
    required this.configuration,
    required this.legacyStore,
  });

  @override
  Future<EditorFormattingPreferences> read() async {
    final legacy = await legacyStore.read();
    final keys = {
      'formatOnSave': 'editor.formatOnSave',
      'formatOnType': 'editor.formatOnType',
      'formatOnPaste': 'editor.formatOnPaste',
      'formatOnSaveMode': 'editor.formatOnSaveMode',
      'defaultFormatter': 'editor.defaultFormatter',
    };
    final values = <String, Object?>{};
    for (final entry in keys.entries) {
      final inspected = configuration.inspect<Object?>(entry.value);
      if (inspected.isConfiguredInSelectedTarget) {
        values[entry.key] = inspected.userValue;
      } else {
        values[entry.key] = switch (entry.key) {
          'formatOnSave' => legacy.formatOnSave,
          'formatOnType' => legacy.formatOnType,
          'formatOnPaste' => legacy.formatOnPaste,
          'formatOnSaveMode' => legacy.formatOnSaveMode.name,
          'defaultFormatter' => legacy.defaultFormatter,
          _ => null,
        };
        final value = values[entry.key];
        if (value != null && value != inspected.defaultValue) {
          await configuration.updateValue(entry.value, value);
        }
      }
    }
    return EditorFormattingPreferences(
      formatOnSave: values['formatOnSave'] as bool? ?? false,
      formatOnType: values['formatOnType'] as bool? ?? false,
      formatOnPaste: values['formatOnPaste'] as bool? ?? false,
      formatOnSaveMode: FormatOnSaveMode.fromJson(values['formatOnSaveMode']),
      defaultFormatter: values['defaultFormatter'] as String?,
      languageOverrides: legacy.languageOverrides,
    );
  }

  @override
  Future<void> write(EditorFormattingPreferences preferences) async {
    await configuration.updateValue(
      'editor.formatOnSave',
      preferences.formatOnSave,
    );
    await configuration.updateValue(
      'editor.formatOnType',
      preferences.formatOnType,
    );
    await configuration.updateValue(
      'editor.formatOnPaste',
      preferences.formatOnPaste,
    );
    await configuration.updateValue(
      'editor.formatOnSaveMode',
      preferences.formatOnSaveMode.name,
    );
    await configuration.updateValue(
      'editor.defaultFormatter',
      preferences.defaultFormatter,
    );
    if (preferences.languageOverrides.isNotEmpty) {
      await legacyStore.write(preferences);
    }
  }
}
