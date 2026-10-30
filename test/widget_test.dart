import 'package:code_editor/code_editor_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/main.dart';
import 'package:code_editor/layout/widgets/workbench_scaffold.dart';
import 'package:code_editor/layout/controllers/layout_controller.dart';
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Editors Open'), findsOneWidget);
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
