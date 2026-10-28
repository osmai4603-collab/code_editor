import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/core/statusbar/contributions/diagnostics_status.dart';
import 'package:code_editor/core/statusbar/contributions/editor_context_status.dart';
import 'package:code_editor/core/statusbar/editor_status_controller.dart';
import 'package:code_editor/core/statusbar/models/status_bar_alignment.dart';
import 'package:code_editor/core/statusbar/status_bar_preferences_store.dart';
import 'package:code_editor/core/statusbar/status_bar_scope.dart';
import 'package:code_editor/core/statusbar/status_bar_service.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/layout/controllers/layout_controller.dart';
import 'package:code_editor/layout/controllers/lsp_and_execution_scope.dart';
import 'package:code_editor/layout/models/layout_state.dart';
import 'package:code_editor/parts/statusbar/statusbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StatusBarService statusBar;
  late EditorDocumentsController documents;
  late EditorStatusController editorStatus;
  late DiagnosticsService diagnostics;
  late WorkbenchLayoutController layout;
  late EditorContextStatusContribution editorContribution;
  late DiagnosticsStatusContribution diagnosticsContribution;

  setUp(() async {
    statusBar = StatusBarService(
      preferencesStore: InMemoryStatusBarPreferencesStore(),
    );
    await statusBar.initialize();
    documents = EditorDocumentsController();
    editorStatus = EditorStatusController();
    diagnostics = DiagnosticsService();
    layout = WorkbenchLayoutController();
    layout.updateState((state) => state.copyWith(isPanelVisible: false));
    editorContribution = EditorContextStatusContribution(
      documents: documents,
      editorStatus: editorStatus,
      statusBar: statusBar,
    );
    diagnosticsContribution = DiagnosticsStatusContribution(
      diagnostics: diagnostics,
      layout: layout,
      statusBar: statusBar,
    );
  });

  tearDown(() {
    editorContribution.dispose();
    diagnosticsContribution.dispose();
    statusBar.dispose();
    documents.dispose();
    editorStatus.dispose();
    diagnostics.dispose();
    layout.dispose();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: EditorTheme(
        theme: EditorThemeData.darkModern,
        child: StatusBarScope(
          notifier: statusBar,
          child: EditorStatusScope(
            notifier: editorStatus,
            child: DiagnosticsScope(
              notifier: diagnostics,
              child: WorkbenchLayoutScope(
                notifier: layout,
                child: EditorDocumentsScope(
                  notifier: documents,
                  child: const Scaffold(body: StatusBarWidget()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('reflects active file, language, cursor, and dirty state', (
    tester,
  ) async {
    documents.openFile(
      title: 'app.dart',
      path: '/workspace/app.dart',
      content: 'one\ntwo',
      languageId: 'dart',
    );
    final tab = documents.activeTab!;
    editorStatus.update(
      tab.id,
      tab.content,
      const TextSelection.collapsed(offset: 5),
    );

    await tester.pumpWidget(buildSubject());
    expect(find.text('app.dart'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('Ln 2, Col 2'), findsOneWidget);

    editorStatus.update(
      tab.id,
      tab.content,
      const TextSelection.collapsed(offset: 2),
    );
    await tester.pump();
    expect(find.text('Ln 1, Col 3'), findsOneWidget);

    documents.updateContent(tab.id, 'changed');
    await tester.pump();
    expect(find.text('app.dart •'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'app.dart (unsaved changes)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('diagnostics update counts and directly select Problems', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    diagnostics.updateDiagnostics('/workspace/app.dart', [
      DiagnosticItem(
        uri: '/workspace/app.dart',
        range: const LspRange(
          start: LspPosition(line: 0, character: 0),
          end: LspPosition(line: 0, character: 1),
        ),
        severity: DiagnosticSeverity.error,
        message: 'Unexpected token',
      ),
      DiagnosticItem(
        uri: '/workspace/app.dart',
        range: const LspRange(
          start: LspPosition(line: 1, character: 0),
          end: LspPosition(line: 1, character: 1),
        ),
        severity: DiagnosticSeverity.warning,
        message: 'Unused value',
      ),
    ]);
    await tester.pump();

    final error = statusBar.entries.firstWhere(
      (entry) => entry.id == 'diagnostics.errors',
    );
    final warning = statusBar.entries.firstWhere(
      (entry) => entry.id == 'diagnostics.warnings',
    );
    expect(error.alignment, StatusBarAlignment.left);
    expect(error.text, '1');
    expect(warning.text, '1');

    await tester.tap(find.text('1').first);
    await tester.pump();
    expect(layout.state.isPanelVisible, isTrue);
    expect(layout.state.activePanelTab, PanelTab.problems);

    diagnostics.clearAll();
    await tester.pump();
    expect(
      statusBar.entries.where((entry) => entry.id.startsWith('diagnostics.')),
      isEmpty,
    );
  });
}
