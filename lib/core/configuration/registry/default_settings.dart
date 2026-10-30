import '../contracts/setting_value_type.dart';
import 'configuration_registry.dart';
import 'setting_definition.dart';

ConfigurationRegistry createDefaultConfigurationRegistry() {
  final registry = ConfigurationRegistry();
  void add<T>(
    String key,
    String title,
    SettingValueType type,
    T? value, {
    String category = 'Commonly Used',
    String description = '',
    List<String> tags = const [],
    int order = 0,
    List<SettingOption> options = const [],
  }) {
    registry.register(
      SettingDefinition<T>(
        key: key,
        title: title,
        type: type,
        defaultValue: value,
        category: category,
        description: description,
        tags: tags,
        order: order,
        options: options,
      ),
    );
  }

  add(
    'editor.fontSize',
    'Font Size',
    SettingValueType.integer,
    14,
    category: 'Text Editor > Font',
    description: 'Controls the font size in pixels.',
    tags: ['font', 'editor'],
    order: 1,
  );
  add(
    'editor.tabSize',
    'Tab Size',
    SettingValueType.integer,
    4,
    category: 'Text Editor > Indentation',
    description: 'The number of spaces a tab is equal to.',
    tags: ['indentation', 'editor'],
    order: 1,
  );
  add(
    'editor.insertSpaces',
    'Insert Spaces',
    SettingValueType.boolean,
    true,
    category: 'Text Editor > Indentation',
    description: 'Insert spaces when pressing Tab.',
    tags: ['indentation'],
    order: 1,
  );
  add(
    'editor.detectIndentation',
    'Detect Indentation',
    SettingValueType.boolean,
    true,
    category: 'Text Editor > Indentation',
    description: 'Detect indentation options from the file contents.',
    tags: ['indentation'],
    order: 2,
  );
  add(
    'editor.formatOnSave',
    'Format On Save',
    SettingValueType.boolean,
    false,
    category: 'Text Editor > Formatting',
    description: 'Format a file on save.',
    tags: ['formatting', 'editor'],
    order: 1,
  );
  add(
    'editor.formatOnType',
    'Format On Type',
    SettingValueType.boolean,
    false,
    category: 'Text Editor > Formatting',
    description: 'Format a line after typing.',
    tags: ['formatting'],
    order: 1,
  );
  add(
    'editor.formatOnPaste',
    'Format On Paste',
    SettingValueType.boolean,
    false,
    category: 'Text Editor > Formatting',
    description: 'Format pasted content.',
    tags: ['formatting'],
    order: 2,
  );
  add(
    'editor.formatOnSaveMode',
    'Format On Save Mode',
    SettingValueType.enumeration,
    'file',
    category: 'Text Editor > Formatting',
    description: 'Controls which parts of a file are formatted on save.',
    tags: ['formatting'],
    order: 3,
    options: const [
      SettingOption(value: 'file', label: 'file'),
      SettingOption(value: 'modifications', label: 'modifications'),
    ],
  );
  add<String>(
    'editor.defaultFormatter',
    'Default Formatter',
    SettingValueType.string,
    null,
    category: 'Text Editor > Formatting',
    description: 'Defines a default formatter for the editor.',
    tags: ['formatting'],
    order: 4,
  );
  add(
    'workbench.colorTheme',
    'Color Theme',
    SettingValueType.enumeration,
    'dark-modern',
    category: 'Workbench > Appearance',
    description: 'Specifies the color theme used in the workbench.',
    tags: ['theme', 'appearance'],
    order: 1,
    options: const [
      SettingOption(value: 'dark-modern', label: 'Dark Modern'),
      SettingOption(value: 'light-modern', label: 'Light Modern'),
    ],
  );
  add(
    'workbench.statusBar.visible',
    'Status Bar: Visible',
    SettingValueType.boolean,
    true,
    category: 'Workbench > Status Bar',
    description: 'Controls the visibility of the status bar.',
    tags: ['statusbar'],
    order: 1,
  );
  add(
    'workbench.statusBar.hiddenItems',
    'Status Bar: Hidden Items',
    SettingValueType.stringList,
    const <String>[],
    category: 'Workbench > Status Bar',
    description: 'Identifiers of status bar entries hidden by the user.',
    tags: ['statusbar'],
    order: 2,
  );
  add(
    'workbench.editor.showTabs',
    'Show Editor Tabs',
    SettingValueType.boolean,
    true,
    category: 'Workbench > Tabs',
    description: 'Controls whether editor tabs are shown.',
    tags: ['tabs'],
    order: 1,
  );
  add(
    'terminal.integrated.fontSize',
    'Font Size',
    SettingValueType.integer,
    14,
    category: 'Terminal > Integrated Terminal',
    description: 'The font size of the terminal.',
    tags: ['terminal', 'font'],
    order: 1,
  );
  add(
    'terminal.integrated.fontFamily',
    'Font Family',
    SettingValueType.string,
    'JetBrains Mono',
    category: 'Terminal > Integrated Terminal',
    description: 'The font family of the terminal.',
    tags: ['terminal', 'font'],
    order: 2,
  );
  add(
    'terminal.integrated.cursorStyle',
    'Cursor Style',
    SettingValueType.enumeration,
    'block',
    category: 'Terminal > Integrated Terminal',
    description: 'The shape of the terminal cursor.',
    tags: ['terminal'],
    order: 3,
    options: const [
      SettingOption(value: 'block', label: 'block'),
      SettingOption(value: 'line', label: 'line'),
      SettingOption(value: 'underline', label: 'underline'),
    ],
  );
  add(
    'files.exclude',
    'Exclude',
    SettingValueType.excludePatterns,
    const <String, bool>{
      '**/.git': true,
      '**/build': true,
      '**/.dart_tool': true,
    },
    category: 'Features > Explorer',
    description: 'Configure patterns to exclude from the file explorer.',
    tags: ['files', 'explorer', 'exclude'],
    order: 1,
  );
  return registry;
}
