import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/editor/indentation/editor_indentation_options.dart';
import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/lsp/client/lsp_client.dart';
import 'package:code_editor/core/lsp/connection/lsp_channel.dart';
import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/registry/lsp_server_registry.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/parts/editor/controllers/editor_lsp_extension.dart';

void main() {
  group('EditorLspExtension document symbols', () {
    late _MockLspChannel channel;
    late LspClient client;
    late DiagnosticsService diagnostics;
    late ExecutionController execution;
    EditorLspExtension? extension;

    Future<void> initializeClient({
      required bool supportsSymbols,
      bool supportsFormatting = false,
    }) async {
      channel = _MockLspChannel();
      client = LspClient(channel: channel);
      final initialize = client.initialize(rootUri: 'file:///workspace');
      final request = channel.messages.single;
      final requestId = (jsonDecode(request) as Map<String, dynamic>)['id'];
      channel.respond(
        requestId,
        result: {
          'capabilities': {
            if (supportsSymbols) 'documentSymbolProvider': true,
            if (supportsFormatting) 'documentFormattingProvider': true,
          },
        },
      );
      await initialize;
      diagnostics = DiagnosticsService();
      execution = ExecutionController();
      extension = EditorLspExtension(
        registry: _TestRegistry(diagnostics, client),
        diagnosticsService: diagnostics,
        executionController: execution,
      );
    }

    tearDown(() async {
      extension?.dispose();
      if (extension != null) {
        diagnostics.dispose();
        execution.dispose();
        await client.close();
      }
    });

    test('requests symbols only when the server advertises support', () async {
      await initializeClient(supportsSymbols: false);
      await extension!.syncActiveTab(_tab);
      await pumpEventQueue();

      expect(_requests(channel, 'textDocument/documentSymbol'), isEmpty);
      expect(extension!.documentSymbols, isEmpty);
    });

    test('ignores a response that arrives after a newer request', () async {
      await initializeClient(supportsSymbols: true);
      await extension!.syncActiveTab(_tab);
      await pumpEventQueue();

      final initialRequest = _requests(
        channel,
        'textDocument/documentSymbol',
      ).single;
      channel.respond(initialRequest['id'], result: []);
      await pumpEventQueue();

      final stale = extension!.fetchDocumentSymbols();
      await pumpEventQueue();
      final staleRequest = _requests(
        channel,
        'textDocument/documentSymbol',
      ).last;

      final latest = extension!.fetchDocumentSymbols();
      await pumpEventQueue();
      final latestRequest = _requests(
        channel,
        'textDocument/documentSymbol',
      ).last;

      channel.respond(latestRequest['id'], result: [_symbol('newer')]);
      await latest;
      channel.respond(staleRequest['id'], result: [_symbol('older')]);
      await stale;

      expect(extension!.documentSymbols.map((symbol) => symbol.name), [
        'newer',
      ]);
    });

    test('sends formatting options and returns server edits', () async {
      await initializeClient(supportsSymbols: false, supportsFormatting: true);
      await extension!.syncActiveTab(_tab);

      final formatting = extension!.formatDocument(
        options: const EditorIndentationOptions(
          tabSize: 2,
          indentSize: 2,
          insertSpaces: false,
        ),
      );
      await pumpEventQueue();

      final request = _requests(channel, 'textDocument/formatting').single;
      expect(request['params']['options'], {
        'tabSize': 2,
        'insertSpaces': false,
      });
      channel.respond(
        request['id'],
        result: [
          {
            'range': {
              'start': {'line': 0, 'character': 0},
              'end': {'line': 0, 'character': 14},
            },
            'newText': 'void main() {}\n',
          },
        ],
      );

      final edits = await formatting;
      expect(edits.single.newText, 'void main() {}\n');
    });

    test(
      'does not apply formatting results for an outdated document',
      () async {
        await initializeClient(
          supportsSymbols: false,
          supportsFormatting: true,
        );
        await extension!.syncActiveTab(_tab);

        final formatting = extension!.formatDocument(
          options: const EditorIndentationOptions(),
        );
        await pumpEventQueue();
        final request = _requests(channel, 'textDocument/formatting').single;
        extension!.onContentChanged('changed while formatting');
        channel.respond(request['id'], result: []);

        expect(formatting, throwsStateError);
      },
    );
  });
}

final _tab = EditorTabItem(
  id: 'tab-1',
  title: 'main.dart',
  path: '/workspace/main.dart',
  content: 'void main() {}',
  languageId: 'dart',
);

Map<String, dynamic> _symbol(String name) => {
  'name': name,
  'kind': 12,
  'range': {
    'start': {'line': 0, 'character': 0},
    'end': {'line': 0, 'character': 14},
  },
  'selectionRange': {
    'start': {'line': 0, 'character': 5},
    'end': {'line': 0, 'character': 9},
  },
};

List<Map<String, dynamic>> _requests(_MockLspChannel channel, String method) =>
    channel.messages
        .map((message) => jsonDecode(message) as Map<String, dynamic>)
        .where((message) => message['method'] == method)
        .toList();

class _TestRegistry extends LspServerRegistry {
  final LspClient _client;

  _TestRegistry(DiagnosticsService diagnosticsService, this._client)
    : super(diagnosticsService: diagnosticsService, autoStart: false);

  @override
  Future<LspClient?> getClientForFile(
    String filePath, {
    required String rootUri,
  }) async => _client;
}

class _MockLspChannel implements LspChannel {
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  final StreamController<String> _stderr = StreamController<String>.broadcast();
  final Completer<int> _exitCode = Completer<int>();
  final List<String> messages = [];
  bool _isClosed = false;

  void respond(dynamic id, {dynamic result, Map<String, dynamic>? error}) {
    _incoming.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        if (error != null) 'error': error else 'result': result,
      }),
    );
  }

  @override
  Stream<String> get incomingMessages => _incoming.stream;

  @override
  Stream<String> get stderrMessages => _stderr.stream;

  @override
  bool get isClosed => _isClosed;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  void sendMessage(String jsonMessage) => messages.add(jsonMessage);

  @override
  Future<void> close() async {
    _isClosed = true;
    await _incoming.close();
    await _stderr.close();
    if (!_exitCode.isCompleted) _exitCode.complete(0);
  }
}
