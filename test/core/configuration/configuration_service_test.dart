import 'package:code_editor/core/configuration/contracts/configuration_service.dart';
import 'package:code_editor/core/configuration/contracts/configuration_target.dart';
import 'package:code_editor/core/configuration/registry/default_settings.dart';
import 'package:code_editor/core/configuration/services/configuration_service.dart';
import 'package:code_editor/core/configuration/stores/configuration_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConfigurationService configuration;

  setUp(() async {
    configuration = ConfigurationService(
      registry: createDefaultConfigurationRegistry(),
      userStore: InMemoryConfigurationStore(),
      workspaceStore: InMemoryConfigurationStore(),
      memoryStore: InMemoryConfigurationStore(),
    );
    await configuration.initialize();
  });

  tearDown(() => configuration.dispose());

  test('applies default, user, workspace, and memory precedence', () async {
    expect(configuration.getValue<int>('editor.tabSize'), 4);
    await configuration.updateValue('editor.tabSize', 2);
    expect(configuration.getValue<int>('editor.tabSize'), 2);
    await configuration.updateValue(
      'editor.tabSize',
      8,
      target: ConfigurationTarget.workspace,
    );
    expect(configuration.getValue<int>('editor.tabSize'), 8);
    await configuration.updateValue(
      'editor.tabSize',
      3,
      target: ConfigurationTarget.memory,
    );
    expect(configuration.getValue<int>('editor.tabSize'), 3);

    final result = configuration.inspect<int>(
      'editor.tabSize',
      target: ConfigurationTarget.workspace,
    );
    expect(result.defaultValue, 4);
    expect(result.userValue, 2);
    expect(result.workspaceValue, 8);
    expect(result.isConfiguredInSelectedTarget, isTrue);
    expect(result.isModified, isTrue);
  });

  test('resets default values by removing the target value', () async {
    await configuration.updateValue('editor.formatOnSave', true);
    expect(configuration.getValue<bool>('editor.formatOnSave'), isTrue);
    await configuration.updateValue('editor.formatOnSave', false);

    expect(configuration.getValue<bool>('editor.formatOnSave'), isFalse);
    expect(
      configuration
          .inspect<bool>('editor.formatOnSave')
          .isConfiguredInSelectedTarget,
      isFalse,
    );
    expect(
      configuration.inspect<bool>('editor.formatOnSave').isModified,
      isFalse,
    );
  });

  test('publishes only the changed key and target', () async {
    final changes = configuration.onDidChangeConfiguration;
    final eventFuture = expectLater(
      changes,
      emits(
        isA<ConfigurationChangeEvent>()
            .having((event) => event.changedKeys, 'changed keys', {
              'editor.tabSize',
            })
            .having(
              (event) => event.target,
              'target',
              ConfigurationTarget.workspace,
            ),
      ),
    );

    await configuration.updateValue(
      'editor.tabSize',
      2,
      target: ConfigurationTarget.workspace,
    );
    await eventFuture;
  });

  test('rejects invalid values and unknown enum options', () async {
    expect(
      () => configuration.updateValue('editor.tabSize', 'four'),
      throwsArgumentError,
    );
    expect(
      () => configuration.updateValue('workbench.colorTheme', 'unknown'),
      throwsArgumentError,
    );
  });
}
