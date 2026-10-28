import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/lsp/client/lsp_client.dart';
import 'package:code_editor/core/lsp/connection/lsp_channel.dart';
import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/core/lsp/registry/lsp_server_registry.dart';

class MockLspChannel implements LspChannel {
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  final StreamController<String> _stderr = StreamController<String>.broadcast();
  final Completer<int> _exitCompleter = Completer<int>();

  final List<String> sentMessages = [];
  bool _isClosed = false;

  void feedIncoming(String rawJson) {
    if (!_incoming.isClosed) {
      _incoming.add(rawJson);
    }
  }

  @override
  Stream<String> get incomingMessages => _incoming.stream;

  @override
  Stream<String> get stderrMessages => _stderr.stream;

  @override
  bool get isClosed => _isClosed;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  void sendMessage(String jsonMessage) {
    sentMessages.add(jsonMessage);
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    if (!_incoming.isClosed) await _incoming.close();
    if (!_stderr.isClosed) await _stderr.close();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(0);
  }
}

void main() {
  group('LspClient & RequestManager Unit Tests', () {
    late MockLspChannel channel;
    late LspClient client;

    setUp(() {
      channel = MockLspChannel();
      client = LspClient(
        channel: channel,
        defaultTimeout: const Duration(seconds: 2),
      );
    });

    tearDown(() async {
      await client.close();
    });

    test(
      'Performs initialize handshake and sends initialized notification',
      () async {
        final initFuture = client.initialize(rootUri: 'file:///workspace');

        expect(channel.sentMessages.length, equals(1));
        final initRequest =
            jsonDecode(channel.sentMessages.first) as Map<String, dynamic>;
        expect(initRequest['method'], equals('initialize'));
        final reqId = initRequest['id'] as int;

        // محاكاة رد الخادم بقدرات
        channel.feedIncoming(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': reqId,
            'result': {
              'capabilities': {
                'textDocumentSync': 1,
                'completionProvider': {'resolveProvider': true},
                'hoverProvider': true,
                'documentFormattingProvider': true,
                'documentRangeFormattingProvider': true,
              },
            },
          }),
        );

        final caps = await initFuture;
        expect(caps.hasCompletion, isTrue);
        expect(caps.hasHover, isTrue);
        expect(caps.hasDocumentFormatting, isTrue);
        expect(caps.hasDocumentRangeFormatting, isTrue);
        expect(caps.textDocumentSync, equals(TextDocumentSyncKind.full));
        expect(client.isInitialized, isTrue);

        // التأكد من إرسال إشعار initialized تلقائياً
        expect(channel.sentMessages.length, equals(2));
        final notif =
            jsonDecode(channel.sentMessages[1]) as Map<String, dynamic>;
        expect(notif['method'], equals('initialized'));
      },
    );

    test(
      'Dispatches publishDiagnostics notification to onDiagnostics stream',
      () async {
        final receivedEvents = <DiagnosticPublishEvent>[];
        client.onDiagnostics.listen((event) {
          receivedEvents.add(event);
        });

        channel.feedIncoming(
          jsonEncode({
            'jsonrpc': '2.0',
            'method': 'textDocument/publishDiagnostics',
            'params': {
              'uri': 'file:///main.dart',
              'diagnostics': [
                {
                  'range': {
                    'start': {'line': 10, 'character': 2},
                    'end': {'line': 10, 'character': 15},
                  },
                  'severity': 1,
                  'message': 'Undefined name "foo"',
                  'source': 'dart',
                },
              ],
            },
          }),
        );

        await pumpEventQueue();

        expect(receivedEvents.length, equals(1));
        expect(receivedEvents.first.uri, equals('file:///main.dart'));
        expect(receivedEvents.first.diagnostics.length, equals(1));
        final diag = receivedEvents.first.diagnostics.first;
        expect(diag.uri, equals('file:///main.dart'));
        expect(diag.severity, equals(DiagnosticSeverity.error));
        expect(diag.message, equals('Undefined name "foo"'));
        expect(diag.range.start.line, equals(10));
      },
    );

    test(
      'Preserves URI and version when publishDiagnostics clears a file',
      () async {
        final events = <DiagnosticPublishEvent>[];
        client.onDiagnostics.listen(events.add);
        channel.feedIncoming(
          jsonEncode({
            'jsonrpc': '2.0',
            'method': 'textDocument/publishDiagnostics',
            'params': {
              'uri': 'file:///workspace/a%20file.dart',
              'version': 8,
              'diagnostics': [],
            },
          }),
        );

        await pumpEventQueue();

        expect(events, hasLength(1));
        expect(events.single.uri, 'file:///workspace/a%20file.dart');
        expect(events.single.version, 8);
        expect(events.single.diagnostics, isEmpty);
      },
    );

    test('Handles request timeouts cleanly', () async {
      final shortTimeoutClient = LspClient(
        channel: channel,
        defaultTimeout: const Duration(milliseconds: 50),
      );

      final resp = await shortTimeoutClient.sendRequest(
        'textDocument/definition',
        {},
      );
      expect(resp.isError, isTrue);
      expect(resp.error?.code, equals(-32800));
      expect(resp.error?.message, contains('timed out'));

      await shortTimeoutClient.close();
    });

    test(
      'Cleanly shuts down with shutdown request and exit notification',
      () async {
        final initFuture = client.initialize(rootUri: 'file:///workspace');
        final initReq =
            jsonDecode(channel.sentMessages.first) as Map<String, dynamic>;
        channel.feedIncoming(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': initReq['id'],
            'result': {'capabilities': {}},
          }),
        );
        await initFuture;

        final shutdownFuture = client.shutdown();
        expect(
          channel.sentMessages.any((m) => m.contains('"shutdown"')),
          isTrue,
        );
        final shutdownReq = channel.sentMessages
            .map((m) => jsonDecode(m) as Map<String, dynamic>)
            .firstWhere((m) => m['method'] == 'shutdown');

        // محاكاة استجابة الخادم لـ shutdown
        channel.feedIncoming(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': shutdownReq['id'],
            'result': null,
          }),
        );

        await shutdownFuture;
        expect(client.isShutdown, isTrue);
        expect(channel.sentMessages.any((m) => m.contains('"exit"')), isTrue);
      },
    );
  });

  group('LspServerRegistry Tests', () {
    test(
      'Correctly registers and identifies GDScript server descriptor for .gd files',
      () {
        final diagService = DiagnosticsService();
        final registry = LspServerRegistry(
          diagnosticsService: diagService,
          autoStart: false,
        );

        final descriptor = registry.findDescriptorForFile('/project/player.gd');
        expect(descriptor, isNotNull);
        expect(descriptor!.languageId, equals('gdscript'));
        expect(descriptor.fileExtensions, contains('.gd'));
        expect(descriptor.command, contains('gdscript_lsp'));
        diagService.dispose();
      },
    );
  });
}
