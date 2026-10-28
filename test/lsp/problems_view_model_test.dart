import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/diagnostics/problems_view_model.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const firstFile = 'file:///workspace/zeta.dart';
  const secondFile = 'file:///workspace/alpha.dart';

  DiagnosticItem diagnostic(
    String uri,
    String message,
    DiagnosticSeverity severity, {
    int line = 0,
    String? source,
    Object? code,
  }) => DiagnosticItem(
    uri: uri,
    range: LspRange(
      start: LspPosition(line: line, character: 0),
      end: LspPosition(line: line, character: 1),
    ),
    severity: severity,
    message: message,
    source: source,
    code: code,
  );

  test('filters by severity and text, and sorts groups and diagnostics', () {
    final diagnostics = {
      firstFile: [
        diagnostic(firstFile, 'later error', DiagnosticSeverity.error, line: 4),
        diagnostic(firstFile, 'warning here', DiagnosticSeverity.warning),
        diagnostic(firstFile, 'earlier error', DiagnosticSeverity.error),
      ],
      secondFile: [
        diagnostic(
          secondFile,
          'unused value',
          DiagnosticSeverity.hint,
          source: 'analyzer',
          code: 'unused',
        ),
      ],
    };

    final filtered = ProblemsViewModel.filterAndSort(
      diagnostics,
      const ProblemsViewFilter(
        query: 'ERROR',
        showErrors: true,
        showWarnings: false,
        showInformation: true,
        showHints: true,
      ),
    );

    expect(filtered.keys, [firstFile]);
    expect(filtered[firstFile]!.map((item) => item.message), [
      'earlier error',
      'later error',
    ]);
  });

  test('searches file path, source, and diagnostic code', () {
    final diagnostics = {
      firstFile: [
        diagnostic(
          firstFile,
          'unrelated message',
          DiagnosticSeverity.warning,
          source: 'lint',
          code: 'prefer_final',
        ),
      ],
    };

    expect(
      ProblemsViewModel.filterAndSort(
        diagnostics,
        const ProblemsViewFilter(query: 'zeta.dart'),
      ).values.single,
      hasLength(1),
    );
    expect(
      ProblemsViewModel.filterAndSort(
        diagnostics,
        const ProblemsViewFilter(query: 'lint'),
      ).values.single,
      hasLength(1),
    );
    expect(
      ProblemsViewModel.filterAndSort(
        diagnostics,
        const ProblemsViewFilter(query: 'prefer_final'),
      ).values.single,
      hasLength(1),
    );
  });

  test('limits results to the active file and handles no active file', () {
    final diagnostics = {
      firstFile: [diagnostic(firstFile, 'one', DiagnosticSeverity.error)],
      secondFile: [diagnostic(secondFile, 'two', DiagnosticSeverity.error)],
    };

    final activeFile = ProblemsViewModel.filterAndSort(
      diagnostics,
      const ProblemsViewFilter(
        onlyActiveFile: true,
        activeFilePath: '/workspace/zeta.dart',
      ),
    );
    expect(activeFile.keys, [
      DiagnosticsService.normalizeUri('/workspace/zeta.dart'),
    ]);

    expect(
      ProblemsViewModel.filterAndSort(
        diagnostics,
        const ProblemsViewFilter(onlyActiveFile: true),
      ),
      isEmpty,
    );
  });
}
