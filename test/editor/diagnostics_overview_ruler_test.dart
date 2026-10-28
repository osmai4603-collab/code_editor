import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/parts/editor/widgets/diagnostics_overview_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosticItem diagnostic(
  int startLine,
  int endLine,
  DiagnosticSeverity severity, {
  int endCharacter = 1,
}) => DiagnosticItem(
  uri: '/workspace/app.dart',
  range: LspRange(
    start: LspPosition(line: startLine, character: 0),
    end: LspPosition(line: endLine, character: endCharacter),
  ),
  severity: severity,
  message: 'issue',
);

void main() {
  group('DiagnosticsOverviewRulerLayout', () {
    test(
      'uses highest severity for overlapping lines and merges neighbors',
      () {
        final markers = DiagnosticsOverviewRulerLayout.buildMarkers([
          diagnostic(0, 2, DiagnosticSeverity.warning),
          diagnostic(1, 1, DiagnosticSeverity.error),
          diagnostic(3, 3, DiagnosticSeverity.warning),
        ], 5);

        expect(markers, const [
          DiagnosticsOverviewRulerMarker(
            startLine: 0,
            endLine: 0,
            severity: DiagnosticSeverity.warning,
          ),
          DiagnosticsOverviewRulerMarker(
            startLine: 1,
            endLine: 1,
            severity: DiagnosticSeverity.error,
          ),
          DiagnosticsOverviewRulerMarker(
            startLine: 2,
            endLine: 3,
            severity: DiagnosticSeverity.warning,
          ),
        ]);
      },
    );

    test('does not include an end line at column zero', () {
      final markers = DiagnosticsOverviewRulerLayout.buildMarkers([
        diagnostic(1, 3, DiagnosticSeverity.information, endCharacter: 0),
      ], 4);

      expect(markers.single.startLine, 1);
      expect(markers.single.endLine, 2);
    });

    test('maps first and last document lines within the ruler bounds', () {
      final first = DiagnosticsOverviewRulerLayout.markerRect(
        marker: const DiagnosticsOverviewRulerMarker(
          startLine: 0,
          endLine: 0,
          severity: DiagnosticSeverity.error,
        ),
        size: const Size(7, 100),
        lineCount: 10,
        lineHeight: 10,
        documentExtent: 100,
      );
      final last = DiagnosticsOverviewRulerLayout.markerRect(
        marker: const DiagnosticsOverviewRulerMarker(
          startLine: 9,
          endLine: 9,
          severity: DiagnosticSeverity.error,
        ),
        size: const Size(7, 100),
        lineCount: 10,
        lineHeight: 10,
        documentExtent: 100,
      );

      expect(first.top, 0);
      expect(last.bottom, 100);
      expect(first.height, greaterThan(0));
    });
  });

  testWidgets('renders as a non-interactive accessible ruler', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorTheme(
          theme: EditorThemeData.darkModern,
          child: const SizedBox(
            width: 7,
            height: 100,
            child: DiagnosticsOverviewRuler(
              diagnostics: [],
              lineCount: 1,
              lineHeight: 20,
              documentExtent: 100,
            ),
          ),
        ),
      ),
    );

    final rulerPaint = find.descendant(
      of: find.byType(DiagnosticsOverviewRuler),
      matching: find.byType(CustomPaint),
    );
    expect(rulerPaint, findsOneWidget);
    expect(
      find.bySemanticsLabel('Diagnostics overview ruler, 0 diagnostics'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DiagnosticsOverviewRuler),
        matching: find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring,
        ),
      ),
      findsOneWidget,
    );
  });
}
