import 'dart:async';

/// واجهة عامة لقناة الاتصال بخادم اللغة (LSP Channel)
///
/// تسمح بتجريد وسيلة النقل الأساسية (Process stdio، WebSockets، أو Sockets).
abstract class LspChannel {
  /// تيار الرسائل الواردة المفككة من الخادم (نصوص JSON نقية)
  Stream<String> get incomingMessages;

  /// تيار أخطاء النظام وسجلات الخادم غير البروتوكولية (stderr)
  Stream<String> get stderrMessages;

  /// إرسال رسالة JSON إلى خادم اللغة
  void sendMessage(String jsonMessage);

  /// إغلاق القناة وإنهاء الاتصال
  Future<void> close();

  /// هل القناة مغلقة حالياً
  bool get isClosed;

  /// كود إنهاء العملية (Exit Code) إن وجد
  Future<int> get exitCode;
}
