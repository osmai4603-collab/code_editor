import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosticItem diagnostic(String uri, String message) => DiagnosticItem(
  uri: uri,
  range: const LspRange(
    start: LspPosition(line: 0, character: 0),
    end: LspPosition(line: 0, character: 1),
  ),
  severity: DiagnosticSeverity.error,
  message: message,
);

void main() {
  late DiagnosticsService service;

  setUp(() => service = DiagnosticsService());
  tearDown(() => service.dispose());

  test('normalizes file URIs and encoded local paths to the same key', () {
    const path = '/workspace/a file-é.dart';
    final uri = Uri.file(path).toString();

    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'error'),
    ]);

    expect(service.getForUri(path), hasLength(1));
    expect(service.getForUri(uri), hasLength(1));
    expect(service.diagnosticsByUri.keys, [uri]);
    expect(DiagnosticsService.pathForUri(uri), path);
  });

  test('normalizes Windows drive paths and file URIs consistently', () {
    const path = r'C:\workspace\a file.dart';
    final uri = Uri.file(path, windows: true).toString();

    expect(
      DiagnosticsService.normalizeUri(path),
      DiagnosticsService.normalizeUri(uri),
    );
  });

  test('combines sources and clears only the requested owner', () {
    const uri = 'file:///workspace/app.dart';
    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'dart issue'),
    ]);
    service.updateDiagnosticsFromSource('python', uri, [
      diagnostic(uri, 'python issue'),
    ]);

    service.updateDiagnosticsFromSource('dart', uri, []);

    expect(service.getForUri('/workspace/app.dart').map((d) => d.message), [
      'python issue',
    ]);
    expect(service.totalProblems, 1);
    service.clearForSource('python');
    expect(service.getForUri(uri), isEmpty);
  });

  test('recursively clears diagnostics beneath a deleted directory', () {
    service.updateDiagnostics('file:///workspace/folder/child.dart', [
      diagnostic('file:///workspace/folder/child.dart', 'child'),
    ]);
    service.updateDiagnostics('file:///workspace/folderish/sibling.dart', [
      diagnostic('file:///workspace/folderish/sibling.dart', 'sibling'),
    ]);

    service.clearForUri('/workspace/folder', recursive: true);

    expect(service.getForUri('/workspace/folder/child.dart'), isEmpty);
    expect(
      service.getForUri('/workspace/folderish/sibling.dart'),
      hasLength(1),
    );
  });

  test('empty and unversioned updates preserve stale-result rejection', () {
    const uri = 'file:///workspace/app.dart';
    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'new'),
    ], version: 10);
    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'stale'),
    ], version: 9);
    expect(service.getForUri(uri).single.message, 'new');

    service.updateDiagnosticsFromSource('dart', uri, []);
    expect(service.getForUri(uri), isEmpty);

    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'late stale'),
    ], version: 8);
    expect(service.getForUri(uri), isEmpty);

    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'current'),
    ], version: 11);
    expect(service.getForUri(uri).single.message, 'current');

    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'unversioned'),
    ]);
    expect(service.getForUri(uri).single.message, 'unversioned');
    service.updateDiagnosticsFromSource('dart', uri, [
      diagnostic(uri, 'stale after unversioned'),
    ], version: 10);
    expect(service.getForUri(uri).single.message, 'unversioned');
  });

  test('returns immutable diagnostic collections', () {
    const uri = 'file:///workspace/app.dart';
    service.updateDiagnostics(uri, [diagnostic(uri, 'issue')]);

    expect(() => service.getForUri(uri).clear(), throwsUnsupportedError);
    expect(() => service.diagnosticsByUri.clear(), throwsUnsupportedError);
  });
}
