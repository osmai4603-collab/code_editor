import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/breadcrumbs/models/breadcrumb_symbol.dart';
import 'package:code_editor/core/breadcrumbs/services/breadcrumb_symbol_path_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_capabilities.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';

void main() {
  group('LspDocumentSymbolResponse', () {
    test('parses hierarchical symbols and their children', () {
      final response = LspDocumentSymbolResponse.fromJson([
        {
          'name': 'Example',
          'kind': 5,
          'range': {
            'start': {'line': 0, 'character': 0},
            'end': {'line': 8, 'character': 1},
          },
          'selectionRange': {
            'start': {'line': 0, 'character': 6},
            'end': {'line': 0, 'character': 13},
          },
          'children': [
            {
              'name': 'build',
              'kind': 6,
              'range': {
                'start': {'line': 2, 'character': 2},
                'end': {'line': 6, 'character': 3},
              },
              'selectionRange': {
                'start': {'line': 2, 'character': 7},
                'end': {'line': 2, 'character': 12},
              },
            },
          ],
        },
      ]);

      expect(response.isHierarchical, isTrue);
      expect(response.documentSymbols.single.name, 'Example');
      expect(response.documentSymbols.single.kind, LspSymbolKind.classKind);
      expect(response.documentSymbols.single.children.single.name, 'build');
    });

    test(
      'parses flat SymbolInformation without inventing parent relationships',
      () {
        final response = LspDocumentSymbolResponse.fromJson([
          {
            'name': 'run',
            'kind': 12,
            'containerName': 'Runner',
            'location': {
              'uri': 'file:///workspace/main.dart',
              'range': {
                'start': {'line': 2, 'character': 0},
                'end': {'line': 5, 'character': 1},
              },
            },
          },
        ]);

        expect(response.isHierarchical, isFalse);
        expect(response.symbolInformation.single.name, 'run');
        expect(response.symbolInformation.single.containerName, 'Runner');
        expect(response.documentSymbols, isEmpty);
      },
    );

    test('treats null and empty responses as no symbols', () {
      expect(LspDocumentSymbolResponse.fromJson(null).documentSymbols, isEmpty);
      expect(LspDocumentSymbolResponse.fromJson([]).symbolInformation, isEmpty);
    });

    test('ignores malformed and reversed symbol ranges', () {
      final response = LspDocumentSymbolResponse.fromJson([
        {
          'name': 'reversed',
          'kind': 12,
          'range': {
            'start': {'line': 3, 'character': 0},
            'end': {'line': 1, 'character': 0},
          },
          'selectionRange': {
            'start': {'line': 3, 'character': 0},
            'end': {'line': 3, 'character': 8},
          },
        },
        {'name': 'missing range', 'kind': 12},
      ]);

      expect(response.documentSymbols, isEmpty);
    });

    test('ignores ranges outside the current document', () {
      final response = LspDocumentSymbolResponse.fromJson(
        [
          {
            'name': 'outside',
            'kind': 12,
            'range': {
              'start': {'line': 1, 'character': 0},
              'end': {'line': 2, 'character': 0},
            },
            'selectionRange': {
              'start': {'line': 1, 'character': 0},
              'end': {'line': 1, 'character': 4},
            },
          },
        ],
        documentText: 'main',
      );

      expect(response.documentSymbols, isEmpty);
    });

    test('validates document symbol provider forms', () {
      expect(
        LspServerCapabilities.fromJson({
          'documentSymbolProvider': true,
        }).hasDocumentSymbol,
        isTrue,
      );
      expect(
        LspServerCapabilities.fromJson({
          'documentSymbolProvider': {'workDoneProgress': true},
        }).hasDocumentSymbol,
        isTrue,
      );
      expect(
        LspServerCapabilities.fromJson({
          'documentSymbolProvider': false,
        }).hasDocumentSymbol,
        isFalse,
      );
    });
  });

  group('BreadcrumbSymbolPathService', () {
    test('returns the nested symbol path containing the cursor', () {
      final parent = _symbol(
        'Class',
        LspSymbolKind.classKind,
        const LspPosition(line: 0, character: 0),
        const LspPosition(line: 8, character: 0),
        children: [
          _symbol(
            'method',
            LspSymbolKind.method,
            const LspPosition(line: 2, character: 0),
            const LspPosition(line: 5, character: 0),
          ),
        ],
      );

      final path = const BreadcrumbSymbolPathService().pathAtPosition([
        parent,
      ], const LspPosition(line: 3, character: 4));

      expect(path.map((symbol) => symbol.name), ['Class', 'method']);
    });

    test('uses half-open ranges and returns no path outside symbols', () {
      final symbol = _symbol(
        'function',
        LspSymbolKind.function,
        const LspPosition(line: 1, character: 0),
        const LspPosition(line: 4, character: 0),
      );
      const service = BreadcrumbSymbolPathService();

      expect(
        service.pathAtPosition([
          symbol,
        ], const LspPosition(line: 1, character: 0)),
        hasLength(1),
      );
      expect(
        service.pathAtPosition([
          symbol,
        ], const LspPosition(line: 4, character: 0)),
        isEmpty,
      );
      expect(
        service.pathAtPosition([
          symbol,
        ], const LspPosition(line: 0, character: 0)),
        isEmpty,
      );
    });
  });
}

BreadcrumbSymbol _symbol(
  String name,
  LspSymbolKind kind,
  LspPosition start,
  LspPosition end, {
  List<BreadcrumbSymbol> children = const [],
}) {
  final range = LspRange(start: start, end: end);
  return BreadcrumbSymbol(
    name: name,
    kind: kind,
    range: range,
    selectionRange: range,
    children: children,
  );
}
