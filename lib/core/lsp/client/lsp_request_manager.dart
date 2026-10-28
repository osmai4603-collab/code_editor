import 'dart:async';
import '../protocol/lsp_message.dart';

/// يدير مطابقة طلبات LSP الصادرة مع الردود الواردة عبر معرّفات الـ id،
/// ويعالج المهل الزمنية (Timeouts) وإلغاء الطلبات المتأخرة.
class LspRequestManager {
  final Duration defaultTimeout;
  int _nextId = 1;

  final Map<int, Completer<LspResponse>> _pendingRequests = {};
  final Map<int, Timer> _requestTimers = {};

  LspRequestManager({this.defaultTimeout = const Duration(seconds: 15)});

  /// توليد معرّف تسلسلي فريد للطلب الجديد
  int nextId() => _nextId++;

  /// تسجيل طلب جديد قيد الانتظار وإرجاع Future ينتظر الاستجابة
  Future<LspResponse> registerRequest(int id, {Duration? timeout}) {
    final completer = Completer<LspResponse>();
    _pendingRequests[id] = completer;

    final effectiveTimeout = timeout ?? defaultTimeout;
    _requestTimers[id] = Timer(effectiveTimeout, () {
      if (_pendingRequests.containsKey(id)) {
        _cleanupRequest(id);
        completer.complete(LspResponse(
          id: id,
          error: LspResponseError(
            code: -32800, // RequestCancelled / Timeout in LSP
            message: 'Request timed out after ${effectiveTimeout.inSeconds} seconds',
          ),
        ));
      }
    });

    return completer.future;
  }

  /// معالجة استجابة واردة من الخادم وتوجيهها للمستدعي المطابق
  bool handleResponse(LspResponse response) {
    final id = response.id;
    if (id == null) return false;

    final completer = _pendingRequests[id];
    if (completer != null && !completer.isCompleted) {
      _cleanupRequest(id);
      completer.complete(response);
      return true;
    }
    return false;
  }

  /// إلغاء طلب معلق محلياً
  bool cancelRequest(int id, {String reason = 'Request was cancelled'}) {
    final completer = _pendingRequests[id];
    if (completer != null && !completer.isCompleted) {
      _cleanupRequest(id);
      completer.complete(LspResponse(
        id: id,
        error: LspResponseError(
          code: -32800,
          message: reason,
        ),
      ));
      return true;
    }
    return false;
  }

  /// إنهاء كافة الطلبات المعلقة في حال انقطاع الاتصال أو إغلاق الخادم
  void failAll(Object error) {
    for (final timer in _requestTimers.values) {
      timer.cancel();
    }
    _requestTimers.clear();

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingRequests.clear();
  }

  void _cleanupRequest(int id) {
    _requestTimers[id]?.cancel();
    _requestTimers.remove(id);
    _pendingRequests.remove(id);
  }

  /// عدد الطلبات العالقة حالياً
  int get pendingCount => _pendingRequests.length;
}
