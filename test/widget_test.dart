import 'package:code_editor/code_editor_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/main.dart';
import 'package:code_editor/layout/widgets/workbench_scaffold.dart';
import 'package:code_editor/layout/controllers/layout_controller.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/parts/titlebar/titlebar_widget.dart';
import 'package:code_editor/parts/activitybar/activitybar_widget.dart';
import 'package:code_editor/parts/sidebar/sidebar_widget.dart';
import 'package:code_editor/parts/editor/editor_area_widget.dart';
import 'package:code_editor/parts/panel/panel_widget.dart';
import 'package:code_editor/parts/statusbar/statusbar_widget.dart';
import 'package:code_editor/parts/sidebar/explorer/explorer_view.dart';
import 'package:code_editor/core/statusbar/status_bar_preferences_store.dart';
import 'package:code_editor/core/editor/formatting/editor_formatting_preferences.dart';
import 'package:code_editor/core/theme/app_theme.dart';
import 'package:code_editor/core/theme/theme_preferences_store.dart';
import 'package:code_editor/core/configuration/registry/default_settings.dart';
import 'package:code_editor/core/configuration/services/configuration_service.dart';
import 'package:code_editor/core/configuration/stores/configuration_store.dart';

ConfigurationService createTestConfigurationService() => ConfigurationService(
  registry: createDefaultConfigurationRegistry(),
  userStore: InMemoryConfigurationStore(),
  workspaceStore: InMemoryConfigurationStore(),
  memoryStore: InMemoryConfigurationStore(),
);

void main() {
  testWidgets('CodeEditor Workbench Scaffold smoke test', (
    WidgetTester tester,
  ) async {
    // محاكاة شاشة حاسوب مكتبية (Desktop resolution 1280x800)
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      CodeEditorApp(
        autoStartLsp: false,
        statusBarPreferencesStore: InMemoryStatusBarPreferencesStore(),
        formattingPreferencesStore: InMemoryEditorFormattingPreferencesStore(),
        themePreferencesStore: InMemoryThemePreferencesStore(),
        configurationService: createTestConfigurationService(),
      ),
    );
    await tester.pumpAndSettle();

    // التحقق من بناء كافة الأجزاء الأساسية للواجهة
    expect(find.byType(WorkbenchScaffold), findsOneWidget);
    expect(find.byType(TitleBarWidget), findsOneWidget);
    expect(find.byType(ActivityBarWidget), findsOneWidget);
    expect(find.byType(SideBarWidget), findsOneWidget);
    expect(find.byType(EditorAreaWidget), findsOneWidget);
    expect(find.byType(PanelWidget), findsOneWidget);
    expect(find.byType(StatusBarWidget), findsOneWidget);

    // المستكشف يعرض مساحة العمل الحقيقية ولا يفتح ملفات استعراضية.
    expect(find.byType(ExplorerView), findsOneWidget);
    expect(find.text('No Editors Open'), findsOneWidget);
    expect(find.text('main.dart'), findsNothing);
    expect(find.text('editor_theme.dart'), findsNothing);
  });

  testWidgets('Empty editor state fits a short window without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      CodeEditorApp(
        autoStartLsp: false,
        statusBarPreferencesStore: InMemoryStatusBarPreferencesStore(),
        formattingPreferencesStore: InMemoryEditorFormattingPreferencesStore(),
        themePreferencesStore: InMemoryThemePreferencesStore(),
        configurationService: createTestConfigurationService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Editors Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opening a file updates editor status after the build frame', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      CodeEditorApp(
        autoStartLsp: false,
        statusBarPreferencesStore: InMemoryStatusBarPreferencesStore(),
        formattingPreferencesStore: InMemoryEditorFormattingPreferencesStore(),
        themePreferencesStore: InMemoryThemePreferencesStore(),
        configurationService: createTestConfigurationService(),
      ),
    );
    await tester.pumpAndSettle();

    final editorContext = tester.element(find.byType(EditorAreaWidget));
    EditorDocumentsScope.of(editorContext).openFile(
      title: 'main.dart',
      path: '/workspace/main.dart',
      content: 'first line\nsecond line',
      languageId: 'dart',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ln 1, Col 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter indents the new line and places the caret after it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      CodeEditorApp(
        autoStartLsp: false,
        statusBarPreferencesStore: InMemoryStatusBarPreferencesStore(),
        formattingPreferencesStore: InMemoryEditorFormattingPreferencesStore(),
        themePreferencesStore: InMemoryThemePreferencesStore(),
        configurationService: createTestConfigurationService(),
      ),
    );
    await tester.pumpAndSettle();

    final editorContext = tester.element(find.byType(EditorAreaWidget));
    EditorDocumentsScope.of(editorContext).openFile(
      title: 'main.dart',
      path: '/workspace/main.dart',
      content:
          'void main() {\n'
          '  WidgetsFlutterBinding.ensureInitialized();\n'
          '  runApp(const CodeEditorApp());\n'
          '}',
      languageId: 'dart',
    );
    await tester.pumpAndSettle();

    final editableTextFinder = find.byType(EditableText).last;
    await tester.tap(editableTextFinder);
    await tester.pump();
    final editableText = tester.widget<EditableText>(editableTextFinder);
    final closingBraceOffset = editableText.controller.text.length - 1;
    editableText.controller.selection = TextSelection.collapsed(
      offset: closingBraceOffset,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    const expectedText =
        'void main() {\n'
        '  WidgetsFlutterBinding.ensureInitialized();\n'
        '  runApp(const CodeEditorApp());\n'
        '  \n'
        '}';
    expect(editableText.controller.text, expectedText);
    expect(
      editableText.controller.selection,
      TextSelection.collapsed(offset: expectedText.lastIndexOf('\n  \n}') + 3),
    );
    final editableState = tester.state<EditableTextState>(editableTextFinder);
    final lineStart = editableState.renderEditable.getLocalRectForCaret(
      TextPosition(offset: editableText.controller.text.lastIndexOf('\n') + 1),
    );
    final caret = editableState.renderEditable.getLocalRectForCaret(
      TextPosition(offset: editableText.controller.selection.extentOffset),
    );
    expect(caret.left, greaterThan(lineStart.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bottom panel shrinks to fit a short workbench', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      CodeEditorApp(
        autoStartLsp: false,
        statusBarPreferencesStore: InMemoryStatusBarPreferencesStore(),
        formattingPreferencesStore: InMemoryEditorFormattingPreferencesStore(),
        themePreferencesStore: InMemoryThemePreferencesStore(),
        configurationService: createTestConfigurationService(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WorkbenchScaffold));
    WorkbenchLayoutScope.of(context).resizePanel(-500);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('theme selection updates and persists across app restart', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final themeStore = InMemoryThemePreferencesStore(themeId: 'light-modern');

    CodeEditorApp createApp() => CodeEditorApp(
      autoStartLsp: false,
      statusBarPreferencesStore: InMemoryStatusBarPreferencesStore(),
      formattingPreferencesStore: InMemoryEditorFormattingPreferencesStore(),
      themePreferencesStore: themeStore,
      configurationService: createTestConfigurationService(),
    );

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    var titleBarContext = tester.element(find.byType(TitleBarWidget));
    expect(AppTheme.of(titleBarContext).id, 'light-modern');
    expect(Theme.of(titleBarContext).brightness, Brightness.light);

    await tester.tap(find.byTooltip('Color Theme: Light Modern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark Modern').last);
    await tester.pumpAndSettle();

    titleBarContext = tester.element(find.byType(TitleBarWidget));
    expect(AppTheme.of(titleBarContext).id, 'dark-modern');
    expect(Theme.of(titleBarContext).brightness, Brightness.dark);
    expect(await themeStore.readThemeId(), 'dark-modern');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    titleBarContext = tester.element(find.byType(TitleBarWidget));
    expect(AppTheme.of(titleBarContext).id, 'dark-modern');
  });
}
