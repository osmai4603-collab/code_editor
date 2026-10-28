import 'dart:io';

import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/parts/panel/views/problems_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late EditorDocumentsController documents;
  late DiagnosticsService diagnostics;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('problems_view_');
    documents = EditorDocumentsController();
    diagnostics = DiagnosticsService();
  });

  tearDown(() async {
    documents.dispose();
    diagnostics.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  DiagnosticItem item(
    String path, {
    required String message,
    required DiagnosticSeverity severity,
    int line = 0,
    int character = 0,
  }) => DiagnosticItem(
    uri: path,
    range: LspRange(
      start: LspPosition(line: line, character: character),
      end: LspPosition(line: line, character: character + 1),
    ),
    severity: severity,
    message: message,
  );

  Widget testApp() => MaterialApp(
    home: EditorTheme(
      theme: EditorThemeData.darkModern,
      child: EditorDocumentsScope(
        notifier: documents,
        child: Scaffold(body: ProblemsView(diagnosticsService: diagnostics)),
      ),
    ),
  );

  testWidgets('filters diagnostics by severity and reports filtered empty', (
    tester,
  ) async {
    final path = '${tempDirectory.path}/sample.dart';
    diagnostics.updateDiagnostics(path, [
      item(
        path,
        message: 'Compilation failed',
        severity: DiagnosticSeverity.error,
      ),
      item(path, message: 'Unused value', severity: DiagnosticSeverity.warning),
    ]);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.text('Compilation failed'), findsOneWidget);
    expect(find.text('Unused value'), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle Errors'));
    await tester.pumpAndSettle();

    expect(find.text('Compilation failed'), findsNothing);
    expect(find.text('Unused value'), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle Warnings'));
    await tester.pumpAndSettle();
    expect(find.text('No problems match the current filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Compilation failed'), findsOneWidget);
    expect(find.text('Unused value'), findsOneWidget);
  });

  testWidgets('selects an open file and requests navigation to its location', (
    tester,
  ) async {
    final path = '${tempDirectory.path}/target.dart';
    documents.openFile(
      title: 'target.dart',
      path: path,
      content: 'first line\nsecond line\nthird line',
    );
    documents.openFile(
      title: 'other.dart',
      path: '${tempDirectory.path}/other.dart',
      content: 'other file',
    );
    diagnostics.updateDiagnostics(path, [
      item(
        path,
        message: 'Inspect this location',
        severity: DiagnosticSeverity.error,
        line: 1,
        character: 2,
      ),
    ]);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Inspect this location'));
    await tester.tap(
      find.ancestor(
        of: find.text('Inspect this location'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(documents.activeTab?.path, path);
    expect(documents.activeTab?.content, 'first line\nsecond line\nthird line');
    expect(documents.navigationRequest?.path, path);
    expect(documents.navigationRequest?.line, 1);
    expect(documents.navigationRequest?.character, 2);
  });

  testWidgets('selects an open dirty file without replacing its contents', (
    tester,
  ) async {
    final path = '${tempDirectory.path}/dirty.dart';
    documents.openFile(
      title: 'dirty.dart',
      path: path,
      content: 'editor version',
    );
    final openedTabId = documents.activeTab!.id;
    documents.updateContent(openedTabId, 'unsaved editor version');
    documents.openFile(
      title: 'other.dart',
      path: '${tempDirectory.path}/other.dart',
      content: 'other file',
    );
    diagnostics.updateDiagnostics(path, [
      item(
        path,
        message: 'Return to dirty file',
        severity: DiagnosticSeverity.warning,
      ),
    ]);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to dirty file'));
    await tester.pumpAndSettle();

    expect(documents.activeTab?.id, openedTabId);
    expect(documents.activeTab?.content, 'unsaved editor version');
    expect(documents.navigationRequest?.path, path);
  });
}
