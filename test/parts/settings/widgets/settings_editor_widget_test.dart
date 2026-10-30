import 'package:code_editor/core/configuration/registry/default_settings.dart';
import 'package:code_editor/core/configuration/services/configuration_service.dart';
import 'package:code_editor/core/configuration/stores/configuration_store.dart';
import 'package:code_editor/core/configuration/widgets/configuration_scope.dart';
import 'package:code_editor/core/theme/app_theme.dart';
import 'package:code_editor/core/theme/app_theme_data.dart';
import 'package:code_editor/parts/settings/widgets/settings_editor_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders searchable settings and controls', (tester) async {
    final configuration = ConfigurationService(
      registry: createDefaultConfigurationRegistry(),
      userStore: InMemoryConfigurationStore(),
      workspaceStore: InMemoryConfigurationStore(),
      memoryStore: InMemoryConfigurationStore(),
    );
    await configuration.initialize();
    addTearDown(configuration.dispose);

    await tester.pumpWidget(
      ConfigurationScope(
        notifier: configuration,
        child: AppTheme(
          theme: AppThemeData.darkModern,
          onThemeChanged: (_) async {},
          child: const MaterialApp(
            home: Scaffold(body: SettingsEditorWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commonly Used'), findsOneWidget);
    expect(find.text('editor.tabSize'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '@tag:formatting');
    await tester.pumpAndSettle();
    expect(find.text('editor.formatOnSave'), findsOneWidget);
    expect(find.text('editor.tabSize'), findsNothing);
  });
}
