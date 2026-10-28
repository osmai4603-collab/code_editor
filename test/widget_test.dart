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
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(WorkbenchScaffold));
    WorkbenchLayoutScope.of(context).resizePanel(-500);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
