import '../../../core/configuration/registry/configuration_registry.dart';
import '../../../core/configuration/registry/setting_definition.dart';

class SettingsCategory {
  final String name;
  final List<SettingsCategory> children;

  const SettingsCategory(this.name, {this.children = const []});
}

class SettingsLayout {
  static const categories = [
    SettingsCategory('Commonly Used'),
    SettingsCategory(
      'Text Editor',
      children: [
        SettingsCategory('Cursor'),
        SettingsCategory('Font'),
        SettingsCategory('Formatting'),
        SettingsCategory('Indentation'),
        SettingsCategory('Files'),
      ],
    ),
    SettingsCategory(
      'Workbench',
      children: [
        SettingsCategory('Appearance'),
        SettingsCategory('Status Bar'),
        SettingsCategory('Tabs'),
      ],
    ),
    SettingsCategory(
      'Terminal',
      children: [
        SettingsCategory('Integrated Terminal'),
        SettingsCategory('Font & Appearance'),
      ],
    ),
    SettingsCategory(
      'Features',
      children: [
        SettingsCategory('Explorer'),
        SettingsCategory('Search'),
        SettingsCategory('Source Control'),
      ],
    ),
  ];

  static List<SettingDefinition<Object?>> settingsFor(
    ConfigurationRegistry registry,
    String category,
  ) {
    if (category == 'Commonly Used') {
      const common = {
        'editor.fontSize',
        'editor.formatOnSave',
        'workbench.colorTheme',
        'editor.tabSize',
        'files.exclude',
      };
      return registry.definitions
          .where((setting) => common.contains(setting.key))
          .toList()
        ..sort((first, second) => first.order.compareTo(second.order));
    }
    return registry.definitions.where((setting) {
      final separator = setting.category.indexOf(' > ');
      final parent = separator == -1
          ? setting.category
          : setting.category.substring(0, separator);
      final child = separator == -1
          ? ''
          : setting.category.substring(separator + 3);
      return setting.category == category ||
          parent == category ||
          child == category;
    }).toList()..sort((first, second) => first.order.compareTo(second.order));
  }
}
