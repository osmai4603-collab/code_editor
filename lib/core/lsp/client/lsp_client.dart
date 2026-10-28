import 'dart:async';
import 'dart:convert';
import '../connection/lsp_channel.dart';
import '../protocol/lsp_capabilities.dart';
import '../protocol/lsp_message.dart';
import '../protocol/lsp_types.dart';
import 'lsp_request_manager.dart';

/// عميل بروتوكول خادم اللغة الأساسي (LSP Client)
///
/// يدير الاتصال وتبادل الرسائل، وتنفيذ المصافحة، ودورة حياة البروتوكول
class LspClient {
  final LspChannel _channel;
  final LspRequestManager _requestManager;

  StreamSubscription<String>? _channelSubscription;
  final StreamController<LspNotification> _notificationController =
      StreamController<LspNotification>.broadcast();
  final StreamController<List<DiagnosticItem>> _diagnosticsController =
      StreamController<List<DiagnosticItem>>.broadcast();

  bool _isInitialized = false;
  bool _isShutdown = false;
  LspServerCapabilities? _serverCapabilities;

  LspClient({
    required this._channel,
    Duration defaultTimeout = const Duration(seconds: 15),
  }) : _requestManager = LspRequestManager(defaultTimeout: defaultTimeout) {
    _listenToChannel();
  }

  bool get isInitialized => _isInitialized;
  bool get isShutdown => _isShutdown;
  LspServerCapabilities? get serverCapabilities => _serverCapabilities;
  LspChannel get channel => _channel;

  /// تيار التشخيصات والأخطاء المجمعة المستلمة من الخادم
  Stream<List<DiagnosticItem>> get onDiagnostics =>
      _diagnosticsController.stream;

  /// تيار الإشعارات العامة
  Stream<LspNotification> get onNotificationStream =>
      _notificationController.stream;

  /// فلترة الإشعارات بحسب اسم الدالة/الحدث
  Stream<LspNotification> onNotification(String method) {
    return _notificationController.stream.where((n) => n.method == method);
  }

  void _listenToChannel() {
    _channelSubscription = _channel.incomingMessages.listen(
      (rawJson) {
        _handleRawMessage(rawJson);
      },
      onError: (err) {
        _requestManager.failAll(err);
      },
      onDone: () {
        _requestManager.failAll(StateError('Lsp channel closed'));
      },
    );
  }

  void _handleRawMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson);
      if (data is! Map<String, dynamic>) return;

      // 1. هل هي استجابة لطلب سابق (تحتوي على id وليس بها method)
      if (data.containsKey('id') && !data.containsKey('method')) {
        final response = LspResponse.fromJson(data);
        _requestManager.handleResponse(response);
        return;
      }

      // 2. هل هو إشعار أحادي الاتجاه (method بدون id)
      if (data.containsKey('method') && !data.containsKey('id')) {
        final notification = LspNotification.fromJson(data);
        _handleNotification(notification);
        return;
      }

      // 3. هل هو طلب من الخادم إلى العميل (Server-to-Client Request)
      if (data.containsKey('method') && data.containsKey('id')) {
        _handleServerRequest(data);
        return;
      }
    } catch (_) {
      // تجاهل الرسائل المشوهة غير القياسية
    }
  }

  void _handleNotification(LspNotification notification) {
    _notificationController.add(notification);

    if (notification.method == 'textDocument/publishDiagnostics') {
      final params = notification.params as Map<String, dynamic>?;
      if (params != null) {
        final uri = params['uri'] as String? ?? '';
        final rawDiagnostics = params['diagnostics'] as List? ?? [];
        final items = rawDiagnostics
            .whereType<Map<String, dynamic>>()
            .map((diag) => DiagnosticItem.fromJson(uri, diag))
            .toList();
        _diagnosticsController.add(items);
      }
    }
  }

  void _handleServerRequest(Map<String, dynamic> data) {
    final id = data['id'];
    final method = data['method'] as String? ?? '';

    // الرد التلقائي على طلبات الخادم القياسية مثل window/showMessageRequest أو client/registerCapability
    if (method == 'workspace/configuration') {
      _channel.sendMessage(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': []}),
      );
    } else {
      _channel.sendMessage(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': null}),
      );
    }
  }

  /// إرسال طلب ينتظر رد الخادم
  Future<LspResponse> sendRequest(
    String method, [
    dynamic params,
    Duration? timeout,
  ]) async {
    if (_channel.isClosed || _isShutdown) {
      throw StateError('Cannot send request to a closed/shutdown LSP client');
    }

    final id = _requestManager.nextId();
    final request = LspRequest(id: id, method: method, params: params);
    final future = _requestManager.registerRequest(id, timeout: timeout);

    _channel.sendMessage(request.serialize());
    return future;
  }

  /// إرسال إشعار بدون انتظار رد
  void sendNotification(String method, [dynamic params]) {
    if (_channel.isClosed || _isShutdown) return;

    final notification = LspNotification(method: method, params: params);
    _channel.sendMessage(notification.serialize());
  }

  /// إلغاء طلب معلق عبر إرسال $/cancelRequest
  void cancelRequest(int id) {
    if (_requestManager.cancelRequest(id)) {
      sendNotification(r'$/cancelRequest', {'id': id});
    }
  }

  /// مصافحة التهيئة الأساسية (Initialize Handshake)
  Future<LspServerCapabilities> initialize({
    required String rootUri,
    String? rootPath,
    Map<String, dynamic>? initializationOptions,
    Map<String, dynamic>? customCapabilities,
  }) async {
    final clientCaps =
        customCapabilities ?? LspClientCapabilities.defaultCapabilities();

    final params = {
      'processId': null,
      'rootUri': rootUri,
      'rootPath':
          rootPath ??
          (rootUri.startsWith('file://') ? rootUri.substring(7) : rootUri),
      'capabilities': clientCaps,
      'trace': 'off',
      'initializationOptions': initializationOptions,
    };

    final response = await sendRequest('initialize', params);
    if (response.isError) {
      throw StateError('LSP Initialize failed: ${response.error?.message}');
    }

    final result = response.result as Map<String, dynamic>? ?? {};
    final capsMap = result['capabilities'] as Map<String, dynamic>?;
    _serverCapabilities = LspServerCapabilities.fromJson(capsMap);

    // إرسال إشعار initialized لتأكيد المصافحة واكتمال التهيئة
    sendNotification('initialized', {});
    _isInitialized = true;

    return _serverCapabilities!;
  }

  /// إغلاق نظيف لـ LSP عبر shutdown ثم exit
  Future<void> shutdown() async {
    if (_isShutdown) return;

    try {
      if (_isInitialized) {
        final resp = await sendRequest(
          'shutdown',
          null,
          const Duration(seconds: 3),
        );
        if (resp.isSuccess) {
          sendNotification('exit');
        }
      }
    } catch (_) {
      // تفادي التوقف في حال تعطل الخادم
    } finally {
      _isShutdown = true;
      _isInitialized = false;
      await close();
    }
  }

  /// إغلاق العميل والقناة وتفريغ الموارد
  Future<void> close() async {
    _channelSubscription?.cancel();
    _requestManager.failAll(StateError('LspClient closed'));
    if (!_notificationController.isClosed) {
      await _notificationController.close();
    }
    if (!_diagnosticsController.isClosed) {
      await _diagnosticsController.close();
    }
    await _channel.close();
  }
}
