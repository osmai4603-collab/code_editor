import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/core/output/output_service.dart';
import 'package:code_editor/core/terminal/services/terminal_scope.dart';
import 'package:code_editor/core/terminal/services/terminal_service.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/layout/controllers/layout_controller.dart';
import 'package:code_editor/layout/controllers/lsp_and_execution_scope.dart';
import 'package:code_editor/layout/models/layout_state.dart';
import 'package:code_editor/parts/panel/panel_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkbenchLayoutController layout;
  late EditorDocumentsController documents;
  late DiagnosticsService diagnostics;
  late ExecutionController execution;
  late OutputService output;
  late TerminalService terminal;

  setUp(() {
    layout = WorkbenchLayoutController()..selectPanelTab(PanelTab.problems);
    documents = EditorDocumentsController();
    diagnostics = DiagnosticsService();
    execution = ExecutionController();
    output = OutputService(execution);
    terminal = TerminalService();
  });

  tearDown(() {
    layout.dispose();
    documents.dispose();
    diagnostics.dispose();
    output.dispose();
    execution.dispose();
    terminal.dispose();
  });

  Widget testApp() => MaterialApp(
    home: EditorTheme(
      theme: EditorThemeData.darkModern,
      child: WorkbenchLayoutScope(
        notifier: layout,
        child: EditorDocumentsScope(
          notifier: documents,
          child: DiagnosticsScope(
            notifier: diagnostics,
            child: ExecutionScope(
              notifier: execution,
              child: OutputScope(
                notifier: output,
                child: TerminalScope(
                  notifier: terminal,
                  child: const Scaffold(body: PanelWidget()),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('keeps panel view state while switching tabs', (tester) async {
    diagnostics.updateDiagnostics('/workspace/main.dart', [
      DiagnosticItem(
        uri: '/workspace/main.dart',
        range: const LspRange(
          start: LspPosition(line: 0, character: 0),
          end: LspPosition(line: 0, character: 1),
        ),
        severity: DiagnosticSeverity.error,
        message: 'Keep this filter',
      ),
    ]);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No problems match the current filters.'), findsOneWidget);

    await tester.tap(find.text('OUTPUT'));
    await tester.pumpAndSettle();
    expect(
      find.text('Run a file to start an execution output session.'),
      findsOneWidget,
    );
    expect(find.byTooltip('New Terminal'), findsNothing);

    await tester.tap(find.text('PROBLEMS'));
    await tester.pumpAndSettle();
    expect(find.text('No problems match the current filters.'), findsOneWidget);
    expect(find.text('Keep this filter'), findsNothing);
  });

  testWidgets('debug console does not offer a fake evaluation prompt', (
    tester,
  ) async {
    layout.selectPanelTab(PanelTab.debugConsole);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('No debug session is available.'), findsOneWidget);
    expect(
      find.text(
        'A Debug Adapter is not connected, so expression evaluation is unavailable.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('panel header fits a narrow window without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
