import 'dart:async';

/// مؤقت تأخير وتجميع تعديلات المستندات (Debouncer) لمنع إغراق خادم اللغة
/// بطلبات didChange متتالية أثناء سرعة الكتابة.
class LspChangeDebouncer {
  final Duration delay;
  final void Function(String uri, String text) onDebouncedChange;

  final Map<String, Timer> _timers = {};
  final Map<String, String> _pendingTexts = {};

  LspChangeDebouncer({
    this.delay = const Duration(milliseconds: 200),
    required this.onDebouncedChange,
  });

  /// تسجيل تعديل جديد على المستند وتأجيل الإرسال
  void recordChange(String uri, String newText) {
    _pendingTexts[uri] = newText;
    _timers[uri]?.cancel();

    _timers[uri] = Timer(delay, () {
      _flushUri(uri);
    });
  }

  /// إرسال التعديل المعلق فوراً للمستند (مثلاً قبل الحفظ أو طلب الإكمال)
  void flush(String uri) {
    _timers[uri]?.cancel();
    _flushUri(uri);
  }

  /// إرسال كافة التعديلات المعلقة لجميع المستندات فوراً
  void flushAll() {
    for (final uri in _pendingTexts.keys.toList()) {
      flush(uri);
    }
  }

  /// إلغاء التعديل المعلق لمستند (عند إغلاقه مثلاً)
  void cancel(String uri) {
    _timers[uri]?.cancel();
    _timers.remove(uri);
    _pendingTexts.remove(uri);
  }

  void _flushUri(String uri) {
    final text = _pendingTexts.remove(uri);
    _timers.remove(uri);
    if (text != null) {
      onDebouncedChange(uri, text);
    }
  }

  /// تفريغ وإغلاق المؤقتات
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingTexts.clear();
  }
}
