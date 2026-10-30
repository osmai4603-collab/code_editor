import 'dart:async';

import 'package:flutter/foundation.dart';

import '../client/lsp_client.dart';
import '../connection/lsp_channel_factory.dart';
import '../diagnostics/diagnostics_service.dart';
import 'lsp_descriptor_source.dart';
import 'language_server_descriptor.dart';

/// السجل المركزي لخوادم اللغات المتعددة (LSP Server Registry)
///
/// يدير تسجيل وتشغيل واستدعاء خوادم اللغات (Dart, Python, Rust, Go, إلخ)
/// ويربط مخرجاتها بالخدمات المركزية مثل التشخيصات (DiagnosticsService).
class LspServerRegistry {
  final DiagnosticsService diagnosticsService;
  final bool autoStart;
  final ILspChannelFactory _channelFactory;
  final List<ILspDescriptorSource> _sources;
  final Set<ILspDescriptorSource> _loadedSources = {};
  final Map<String, LanguageServerDescriptor> _descriptors = {};
  final Map<String, LspClient> _activeClients = {};
  final Map<String, StreamSubscription> _diagnosticSubscriptions = {};
  Future<void>? _sourceLoadFuture;

  LspServerRegistry({
    required this.diagnosticsService,
    this.autoStart = true,
    ILspChannelFactory? channelFactory,
    Iterable<ILspDescriptorSource> descriptorSources = const [],
  }) : _channelFactory = channelFactory ?? ProcessLspChannelFactory(),
       _sources = [BuiltInLspDescriptorSource(), ...descriptorSources] {
    for (final descriptor
        in (_sources.first as BuiltInLspDescriptorSource).descriptors) {
      register(descriptor);
    }
    _loadedSources.add(_sources.first);
  }

  /// Adds a source whose descriptors are loaded when the registry is used.
  void registerSource(ILspDescriptorSource source) {
    if (_sources.contains(source)) return;
    _sources.add(source);
    _sourceLoadFuture = null;
  }

  /// تسجيل توصيف خادم لغة جديد
  void register(LanguageServerDescriptor descriptor) {
    _descriptors[descriptor.id] = descriptor;
  }

  /// البحث عن التوصيف المناسب لملف معين
  LanguageServerDescriptor? findDescriptorForFile(String filePath) {
    for (final desc in _descriptors.values) {
      if (desc.matches(filePath)) {
        return desc;
      }
    }
    return null;
  }

  /// الحصول على عميل LSP نشط أو إطلاقه للملف المحدد
  Future<LspClient?> getClientForFile(
    String filePath, {
    required String rootUri,
  }) async {
    if (!autoStart) return null;

    LspClient? client;
    String? descriptorId;
    try {
      await _loadSources();
      final descriptor = findDescriptorForFile(filePath);
      if (descriptor == null) return null;
      descriptorId = descriptor.id;

      final existing = _activeClients[descriptor.id];
      if (existing != null &&
          !existing.channel.isClosed &&
          existing.isInitialized) {
        return existing;
      }
      if (existing != null) await _retireClient(descriptor.id, existing);

      final channel = await _channelFactory.createChannel(descriptor);

      final startedClient = LspClient(channel: channel);
      client = startedClient;
      _diagnosticSubscriptions[descriptor.id] = startedClient.onDiagnostics
          .listen(
            (event) => diagnosticsService.updateDiagnosticsFromSource(
              descriptor.id,
              event.uri,
              event.diagnostics,
              version: event.version,
            ),
            onDone: () {
              if (identical(_activeClients[descriptor.id], client)) {
                _activeClients.remove(descriptor.id);
                _diagnosticSubscriptions.remove(descriptor.id);
                diagnosticsService.clearForSource(descriptor.id);
              }
            },
          );

      // إتمام المصافحة
      await startedClient.initialize(
        rootUri: rootUri,
        initializationOptions: descriptor.initializationOptions,
      );

      _activeClients[descriptor.id] = startedClient;
      return startedClient;
    } catch (error) {
      if (descriptorId != null) {
        await _diagnosticSubscriptions.remove(descriptorId)?.cancel();
      }
      await client?.close();
      if (descriptorId != null) {
        diagnosticsService.clearForSource(descriptorId);
      }
      debugPrint('Failed to start language server for $filePath: $error');
      return null;
    }
  }

  Future<void> _loadSources() {
    final existing = _sourceLoadFuture;
    if (existing != null) return existing;

    late final Future<void> loading;
    loading = _loadRegisteredSources().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (identical(_sourceLoadFuture, loading)) _sourceLoadFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    _sourceLoadFuture = loading;
    return loading;
  }

  Future<void> _loadRegisteredSources() async {
    for (final source in _sources) {
      if (_loadedSources.contains(source)) continue;
      final descriptors = await source.loadDescriptors();
      for (final descriptor in descriptors) {
        register(descriptor);
      }
      _loadedSources.add(source);
    }
  }

  Future<void> _retireClient(String id, LspClient client) async {
    await _diagnosticSubscriptions.remove(id)?.cancel();
    if (identical(_activeClients[id], client)) _activeClients.remove(id);
    diagnosticsService.clearForSource(id);
    await client.close();
  }

  /// إنهاء كافة خوادم اللغات النشطة
  Future<void> shutdownAll() async {
    for (final sub in _diagnosticSubscriptions.values) {
      await sub.cancel();
    }
    _diagnosticSubscriptions.clear();

    for (final id in _activeClients.keys.toList()) {
      diagnosticsService.clearForSource(id);
    }
    for (final client in _activeClients.values) {
      await client.shutdown();
    }
    _activeClients.clear();
  }
}
