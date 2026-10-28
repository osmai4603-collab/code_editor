import 'package:code_editor/core/lsp/diagnostics/diagnostic_range_utils.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosticItem diagnostic(
  int startLine,
  int startCharacter,
  int endLine,
  int endCharacter,
  DiagnosticSeverity severity,
) => DiagnosticItem(
  uri: '/workspace/app.dart',
  range: LspRange(
    start: LspPosition(line: startLine, character: startCharacter),
    end: LspPosition(line: endLine, character: endCharacter),
  ),
  severity: severity,
  message: 'diagnostic',
);

void main() {
  test('does not include the next line when a range ends at column zero', () {
    final range = LspRange(
      start: const LspPosition(line: 1, character: 2),
      end: const LspPosition(line: 3, character: 0),
    );

    expect(DiagnosticRangeUtils.lastCoveredLine(range), 2);
  });

  test('resolves overlapping severities by stable priority', () {
    final diagnostics = [
      diagnostic(0, 0, 0, 5, DiagnosticSeverity.warning),
      diagnostic(0, 2, 0, 4, DiagnosticSeverity.error),
    ];

    expect(
      DiagnosticRangeUtils.highestSeverityForLineSegment(
        diagnostics: diagnostics,
        line: 0,
        segmentStart: 2,
        segmentEnd: 4,
        lineLength: 5,
      ),
      DiagnosticSeverity.error,
    );
    expect(
      DiagnosticRangeUtils.highestSeverityForLineSegment(
        diagnostics: diagnostics,
        line: 0,
        segmentStart: 0,
        segmentEnd: 2,
        lineLength: 5,
      ),
      DiagnosticSeverity.warning,
    );
  });

  test('clamps out-of-range columns and ignores empty text ranges', () {
    final empty = diagnostic(0, 20, 0, 20, DiagnosticSeverity.hint);
    expect(
      DiagnosticRangeUtils.highestSeverityForLineSegment(
        diagnostics: [empty],
        line: 0,
        segmentStart: 0,
        segmentEnd: 3,
        lineLength: 3,
      ),
      isNull,
    );

    final beyondText = diagnostic(0, 1, 0, 20, DiagnosticSeverity.information);
    expect(DiagnosticRangeUtils.boundsForLine(beyondText.range, 0, 3), [1, 3]);
  });

  test('preserves LSP UTF-16 columns for supplementary characters', () {
    const text = '😀x';
    final item = diagnostic(0, 2, 0, 3, DiagnosticSeverity.error);
    final bounds = DiagnosticRangeUtils.boundsForLine(
      item.range,
      0,
      text.length,
    )!;

    expect(text.substring(bounds[0], bounds[1]), 'x');
  });

  test('keeps the protocol model default for unknown severities', () {
    expect(DiagnosticSeverity.fromValue(99), DiagnosticSeverity.error);
  });
}
