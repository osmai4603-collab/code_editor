import '../../../core/configuration/contracts/configuration_inspect_result.dart';
import '../../../core/configuration/registry/setting_definition.dart';

abstract class SettingsTreeElement {
  const SettingsTreeElement();
}

class SettingsTreeGroupElement extends SettingsTreeElement {
  final String label;
  final List<SettingsTreeElement> children;

  const SettingsTreeGroupElement(this.label, this.children);
}

class SettingsTreeSettingElement extends SettingsTreeElement {
  final SettingDefinition<Object?> definition;
  final ConfigurationInspectResult<Object?> inspectResult;

  const SettingsTreeSettingElement(this.definition, this.inspectResult);
}
