import 'package:code_editor/core/configuration/stores/configuration_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads saved string lists from legacy preference keys', () async {
    SharedPreferences.setMockInitialValues({
      'configuration.user.workbench.statusBar.hiddenItems': [
        'diagnostics',
        'encoding',
      ],
    });

    final values = await const SharedPreferencesConfigurationStore().readAll();

    expect(values['workbench.statusBar.hiddenItems'], [
      'diagnostics',
      'encoding',
    ]);
  });

  test('rejects legacy lists containing unsupported values', () async {
    SharedPreferences.setMockInitialValues({
      'configuration.user.invalid': ['valid', 42],
    });

    await expectLater(
      const SharedPreferencesConfigurationStore().readAll(),
      throwsFormatException,
    );
  });
}
