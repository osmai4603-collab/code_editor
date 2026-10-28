import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/parts/editor/controllers/code_editor_controller.dart';
import 'package:code_editor/parts/editor/widgets/editor_diagnostic_messages_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<TextSpan> _textSpans(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* _textSpans(child);
  }
}

DiagnosticItem _diagnostic(
  String uri,
  int startLine,
  int startCharacter,
  int endLine,
  int endCharacter,
  DiagnosticSeverity severity,
) => DiagnosticItem(
  uri: uri,
  range: LspRange(
    start: LspPosition(line: startLine, character: startCharacter),
    end: LspPosition(line: endLine, character: endCharacter),
  ),
  severity: severity,
  message: 'issue',
);

void main() {
  test('builds one colored inline message per line using highest severity', () {
    final messages = EditorDiagnosticMessagesPainter.messagesForDiagnostics([
      _diagnostic(
        '/workspace/app.dart',
        1,
        0,
        1,
        2,
        DiagnosticSeverity.warning,
      ),
      _diagnostic('/workspace/app.dart', 1, 2, 1, 4, DiagnosticSeverity.error),
      _diagnostic(
        '/workspace/app.dart',
        3,
        0,
        3,
        1,
        DiagnosticSeverity.information,
      ),
    ], 4);

    expect(messages, hasLength(2));
    expect(messages[0].line, 1);
    expect(messages[0].message, 'issue');
    expect(messages[0].severity, DiagnosticSeverity.error);
    expect(messages[1].line, 3);
    expect(messages[1].severity, DiagnosticSeverity.information);
  });

  test('keeps at least 50 pixels between code and diagnostic text', () {
    expect(
      EditorDiagnosticMessagesPainter.messageGap,
      greaterThanOrEqualTo(50),
    );
  });

  testWidgets('highlights matching brackets and occurrences at the caret', (
    tester,
  ) async {
    const filePath = '/workspace/app.dart';
    const text = 'final total = (count + count);';
    final controller = CodeEditorController(text: text, filePath: filePath);
    late TextSpan renderedSpan;

    await tester.pumpWidget(
      MaterialApp(
        home: EditorTheme(
          theme: EditorThemeData.darkModern,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Builder(
              builder: (context) {
                renderedSpan = controller.buildTextSpan(
                  context: context,
                  style: const TextStyle(),
                  withComposing: false,
                );
                return Text.rich(renderedSpan);
              },
            ),
          ),
        ),
      ),
    );

    controller.selection = const TextSelection.collapsed(offset: 14);
    await tester.pump();
    var highlighted = _textSpans(
      renderedSpan,
    ).where((span) => span.style?.backgroundColor != null).toList();
    expect(highlighted.map((span) => span.text), ['(', ')']);

    controller.selection = const TextSelection.collapsed(offset: 18);
    await tester.pump();
    highlighted = _textSpans(
      renderedSpan,
    ).where((span) => span.style?.backgroundColor != null).toList();
    expect(highlighted.map((span) => span.text), ['count', 'count']);

    controller.dispose();
  });

  testWidgets('decorates exact ranges by severity across lines', (
    tester,
  ) async {
    const filePath = '/workspace/app.dart';
    final diagnostics = DiagnosticsService();
    diagnostics.updateDiagnosticsFromSource('dart', filePath, [
      _diagnostic(filePath, 0, 1, 1, 1, DiagnosticSeverity.information),
      _diagnostic(filePath, 0, 2, 0, 3, DiagnosticSeverity.error),
    ]);
    final controller = CodeEditorController(
      text: 'abc\ndef',
      filePath: filePath,
      diagnosticsService: diagnostics,
    );
    late TextSpan renderedSpan;

    await tester.pumpWidget(
      MaterialApp(
        home: EditorTheme(
          theme: EditorThemeData.darkModern,
          child: Builder(
            builder: (context) {
              renderedSpan = controller.buildTextSpan(
                context: context,
                style: const TextStyle(),
                withComposing: false,
              );
              return Text.rich(renderedSpan);
            },
          ),
        ),
      ),
    );

    final decorated = _textSpans(renderedSpan)
        .where((span) => span.style?.decoration == TextDecoration.underline)
        .toList();
    expect(decorated.map((span) => span.text), ['b', 'c', 'd']);
    expect(decorated.map((span) => span.style?.decorationColor), [
      EditorThemeData.darkModern.diagnosticInformation,
      EditorThemeData.darkModern.diagnosticError,
      EditorThemeData.darkModern.diagnosticInformation,
    ]);

    var notifications = 0;
    controller.addListener(() => notifications++);
    diagnostics.updateDiagnosticsFromSource('dart', filePath, []);
    expect(notifications, 1);
    controller.dispose();
    diagnostics.dispose();
  });
}
