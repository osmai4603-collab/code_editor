import 'dart:async';
import 'dart:io';
import '../client/lsp_client.dart';
import '../connection/lsp_process_channel.dart';
import '../diagnostics/diagnostics_service.dart';
import 'language_server_descriptor.dart';

/// السجل المركزي لخوادم اللغات المتعددة (LSP Server Registry)
///
/// يدير تسجيل وتشغيل واستدعاء خوادم اللغات (Dart, Python, Rust, Go, إلخ)
/// ويربط مخرجاتها بالخدمات المركزية مثل التشخيصات (DiagnosticsService).
class LspServerRegistry {
  final DiagnosticsService diagnosticsService;
  final bool autoStart;
  final Map<String, LanguageServerDescriptor> _descriptors = {};
  final Map<String, LspClient> _activeClients = {};
  final Map<String, StreamSubscription> _diagnosticSubscriptions = {};

  LspServerRegistry({
    required this.diagnosticsService,
    this.autoStart = true,
  }) {
    _registerDefaultDescriptors();
  }

  void _registerDefaultDescriptors() {
    // 1. خادم لغة Dart الافتراضي
    register(LanguageServerDescriptor(
      id: 'dart',
      name: 'Dart Language Server',
      languageId: 'dart',
      fileExtensions: const ['.dart'],
      command: _findDartExecutable(),
      args: const ['language-server', '--protocol=lsp'],
    ));

    // 2. خادم لغة Python (Pyright / Pylsp)
    register(const LanguageServerDescriptor(
      id: 'python',
      name: 'Python Pyright',
      languageId: 'python',
      fileExtensions: ['.py'],
      command: 'pyright-langserver',
      args: ['--stdio'],
    ));

    // 3. خادم GDScript LSP المستقل المجمّع (AOT) المبني فوق gdscript_engine
    const compiledGdscriptLsp = '/home/osm/flutter_projects/gdscript_lsp/build/gdscript_lsp';
    const sourceGdscriptLsp = '/home/osm/flutter_projects/gdscript_lsp/bin/gdscript_lsp.dart';
    if (File(compiledGdscriptLsp).existsSync()) {
      register(const LanguageServerDescriptor(
        id: 'gdscript',
        name: 'GDScript Language Server',
        languageId: 'gdscript',
        fileExtensions: ['.gd'],
        command: compiledGdscriptLsp,
        args: [],
      ));
    } else if (File(sourceGdscriptLsp).existsSync()) {
      register(LanguageServerDescriptor(
        id: 'gdscript',
        name: 'GDScript Language Server',
        languageId: 'gdscript',
        fileExtensions: const ['.gd'],
        command: _findDartExecutable(),
        args: const ['run', sourceGdscriptLsp],
      ));
    }
  }

  static String _findDartExecutable() {
    // التحقق من وجود مسار بيئة التطوير المعروف في النظام أو مسار flutter dart
    const knownPaths = [
      '/home/osm/.development/flutter/bin/dart',
      '/home/osm/.development/flutter/bin/cache/dart-sdk/bin/dart',
    ];
    for (final path in knownPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return 'dart';
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

    final descriptor = findDescriptorForFile(filePath);
    if (descriptor == null) return null;

    final existing = _activeClients[descriptor.id];
    if (existing != null && !existing.channel.isClosed && existing.isInitialized) {
      return existing;
    }

    try {
      final channel = await LspProcessChannel.start(
        executable: descriptor.command,
        args: descriptor.args,
        environment: descriptor.environment,
      );

      final client = LspClient(channel: channel);

      // الاستماع للتشخيصات وتوجيهها لخدمة المشاكل المركزية
      _diagnosticSubscriptions[descriptor.id] = client.onDiagnostics.listen((diags) {
        if (diags.isNotEmpty) {
          final uri = diags.first.uri;
          diagnosticsService.updateDiagnostics(uri, diags);
        }
      });

      // إتمام المصافحة
      await client.initialize(
        rootUri: rootUri,
        initializationOptions: descriptor.initializationOptions,
      );

      _activeClients[descriptor.id] = client;
      return client;
    } catch (_) {
      // إذا فشل إطلاق العملية (مثلاً الأداة غير مثبتة في النظام)
      return null;
    }
  }

  /// إنهاء كافة خوادم اللغات النشطة
  Future<void> shutdownAll() async {
    for (final sub in _diagnosticSubscriptions.values) {
      await sub.cancel();
    }
    _diagnosticSubscriptions.clear();

    for (final client in _activeClients.values) {
      await client.shutdown();
    }
    _activeClients.clear();
  }
}
