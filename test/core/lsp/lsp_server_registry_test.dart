import 'dart:async';
import 'dart:convert';

import 'package:code_editor/core/lsp/connection/lsp_channel.dart';
import 'package:code_editor/core/lsp/connection/lsp_channel_factory.dart';
import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/lsp/registry/language_server_descriptor.dart';
import 'package:code_editor/core/lsp/registry/lsp_descriptor_source.dart';
import 'package:code_editor/core/lsp/registry/lsp_server_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _DescriptorSource implements ILspDescriptorSource {
  int loads = 0;

  @override
  Future<List<LanguageServerDescriptor>> loadDescriptors() async {
    loads++;
    return const [
      LanguageServerDescriptor(
        id: 'custom',
        name: 'Custom server',
        languageId: 'custom',
        fileExtensions: ['.custom'],
        command: 'custom-server',
      ),
    ];
  }
}

class _ChannelFactory implements ILspChannelFactory {
  final _channel = _MockLspChannel();
  final List<LanguageServerDescriptor> createdFor = [];

  @override
  Future<LspChannel> createChannel(LanguageServerDescriptor descriptor) async {
    createdFor.add(descriptor);
    return _channel;
  }
}

class _MockLspChannel implements LspChannel {
  final _incoming = StreamController<String>.broadcast();
  final _stderr = StreamController<String>.broadcast();
  final _exitCode = Completer<int>();
  bool _isClosed = false;

  @override
  Stream<String> get incomingMessages => _incoming.stream;
  @override
  Stream<String> get stderrMessages => _stderr.stream;
  @override
  bool get isClosed => _isClosed;
  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  void sendMessage(String jsonMessage) {
    final message = jsonDecode(jsonMessage) as Map<String, dynamic>;
    final method = message['method'];
    if (method != 'initialize' && method != 'shutdown') return;
    scheduleMicrotask(() {
      if (_isClosed) return;
      _incoming.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': message['id'],
          'result': method == 'initialize' ? {'capabilities': {}} : null,
        }),
      );
    });
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    if (!_incoming.isClosed) await _incoming.close();
    if (!_stderr.isClosed) await _stderr.close();
    if (!_exitCode.isCompleted) _exitCode.complete(0);
  }
}

void main() {
  test('loads descriptors from sources and creates a client through a factory',
      () async {
    final source = _DescriptorSource();
    final factory = _ChannelFactory();
    final registry = LspServerRegistry(
      diagnosticsService: DiagnosticsService(),
      descriptorSources: [source],
      channelFactory: factory,
    );

    final client = await registry.getClientForFile(
      '/workspace/main.custom',
      rootUri: 'file:///workspace',
    );

    expect(source.loads, 1);
    expect(factory.createdFor.single.id, 'custom');
    expect(client?.isInitialized, isTrue);
    expect(
      registry.findDescriptorForFile('/workspace/main.custom')?.languageId,
      'custom',
    );

    await registry.shutdownAll();
  });
}
