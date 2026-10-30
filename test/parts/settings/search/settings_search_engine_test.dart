import 'package:code_editor/core/configuration/registry/default_settings.dart';
import 'package:code_editor/core/configuration/services/configuration_service.dart';
import 'package:code_editor/core/configuration/stores/configuration_store.dart';
import 'package:code_editor/parts/settings/search/settings_search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConfigurationService configuration;
  late SettingsSearchEngine engine;

  setUp(() async {
    configuration = ConfigurationService(
      registry: createDefaultConfigurationRegistry(),
      userStore: InMemoryConfigurationStore(),
      workspaceStore: InMemoryConfigurationStore(),
      memoryStore: InMemoryConfigurationStore(),
    );
    await configuration.initialize();
    engine = SettingsSearchEngine();
  });

  tearDown(() => configuration.dispose());

  List<String> keys(String query) => engine
      .search(
        configuration.registry.definitions,
        query,
        inspect: (key) => configuration.inspect<Object?>(key),
      )
      .map((result) => result.setting.key)
      .toList();

  test('matches setting ids and terms in descriptions', () {
    expect(keys('@id:editor.tab'), contains('editor.tabSize'));
    expect(keys('spaces when pressing'), contains('editor.insertSpaces'));
  });

  test('filters modified values and tags', () async {
    await configuration.updateValue('editor.tabSize', 2);

    expect(keys('@modified'), ['editor.tabSize']);
    expect(keys('@tag:font'), contains('editor.fontSize'));
    expect(keys('@tag:formatting'), contains('editor.formatOnSave'));
  });
}
