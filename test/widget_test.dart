import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/main.dart';
import 'package:code_editor/layout/widgets/workbench_scaffold.dart';
import 'package:code_editor/parts/titlebar/titlebar_widget.dart';
import 'package:code_editor/parts/activitybar/activitybar_widget.dart';
import 'package:code_editor/parts/sidebar/sidebar_widget.dart';
import 'package:code_editor/parts/editor/editor_area_widget.dart';
import 'package:code_editor/parts/panel/panel_widget.dart';
import 'package:code_editor/parts/statusbar/statusbar_widget.dart';
import 'package:code_editor/parts/sidebar/explorer/explorer_view.dart';

void main() {
  testWidgets('CodeEditor Workbench Scaffold smoke test', (
    WidgetTester tester,
  ) async {
    // محاكاة شاشة حاسوب مكتبية (Desktop resolution 1280x800)
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CodeEditorApp(autoStartLsp: false));
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
}
