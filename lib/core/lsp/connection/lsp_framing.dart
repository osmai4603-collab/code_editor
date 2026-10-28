import 'dart:convert';
import 'dart:typed_data';

/// المسؤول عن تأطير (Framing) وفك تأطير رسائل LSP المعيارية (JSON-RPC 2.0 عبر stdio).
///
/// صيغة الترويسة القياسية:
/// `Content-Length: <byte_count>\r\n`
/// (\r\n إضافية اختيارية لترويسات أخرى)
/// \r\n
/// `<utf-8 encoded json string>`
class LspFraming {
  static const String _contentLengthHeader = 'Content-Length: ';
  static const String _crlf = '\r\n';
  static const String _headerDelimiter = '\r\n\r\n';

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// ترميز محتوى JSON-RPC وإضافة الترويسات القياسية له.
  static Uint8List encode(String jsonContent) {
    final bytes = utf8.encode(jsonContent);
    final header = '$_contentLengthHeader${bytes.length}$_headerDelimiter';
    final headerBytes = ascii.encode(header);

    final builder = BytesBuilder(copy: false)
      ..add(headerBytes)
      ..add(bytes);
    return builder.takeBytes();
  }

  /// استقبال دفعة بايتات جديدة ومعالجتها، واستخراج جميع الرسائل الكاملة المتاحة.
  ///
  /// يعالج الحالات التالية بكفاءة تامة:
  /// 1. تجزئة الحزم (Fragmentation) عبر أجزاء تيار الشبكة / العمليات.
  /// 2. تجميع عدة رسائل في حزمة واحدة (Batching).
  /// 3. الرموز متعددة البايتات في ترميز UTF-8 (مثل الحروف العربية والرموز التعبيرية).
  List<String> addBytes(List<int> chunk) {
    _buffer.add(chunk);
    final messages = <String>[];

    while (true) {
      final currentBytes = _buffer.toBytes();
      if (currentBytes.isEmpty) break;

      // البحث عن فاصل نهاية الترويسات \r\n\r\n
      final delimiterIndex = _findHeaderDelimiter(currentBytes);
      if (delimiterIndex == -1) {
        // لم تكتمل الترويسات بعد
        break;
      }

      // قراءة الترويسة كـ ASCII
      final headerString = ascii.decode(
        currentBytes.sublist(0, delimiterIndex),
        allowInvalid: true,
      );

      final contentLength = _parseContentLength(headerString);
      if (contentLength == null) {
        // ترويسة غير صالحة - تفريغ حتى الفاصل لتفادي التعليق
        final remaining = currentBytes.sublist(delimiterIndex + 4);
        _buffer.clear();
        _buffer.add(remaining);
        continue;
      }

      final bodyStartIndex = delimiterIndex + 4; // طول \r\n\r\n هو 4 بايت
      final totalMessageLength = bodyStartIndex + contentLength;

      if (currentBytes.length < totalMessageLength) {
        // محتوى الرسالة لم يكتمل بعد في المخزن المؤقت
        break;
      }

      // استخراج جسم الرسالة الكامل وفك تشفيره بـ UTF-8
      final bodyBytes = currentBytes.sublist(
        bodyStartIndex,
        totalMessageLength,
      );
      final jsonString = utf8.decode(bodyBytes, allowMalformed: false);
      messages.add(jsonString);

      // إبقاء ما تبقى في المخزن المؤقت
      final remainingBytes = currentBytes.sublist(totalMessageLength);
      _buffer.clear();
      _buffer.add(remainingBytes);
    }

    return messages;
  }

  /// تفريغ المخزن المؤقت في حال إعادة التهيئة
  void clear() {
    _buffer.clear();
  }

  /// حجم البايتات العالقة حالياً بانتظار استكمال الرسالة
  int get bufferLength => _buffer.length;

  /// البحث عن تسلسل البايتات الخاص بـ \r\n\r\n ([13, 10, 13, 10])
  int _findHeaderDelimiter(Uint8List bytes) {
    for (int i = 0; i <= bytes.length - 4; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  /// استخراج قيمة Content-Length من نص الترويسات
  int? _parseContentLength(String headerBlock) {
    final lines = headerBlock.split(_crlf);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('content-length:')) {
        final valueStr = trimmed.substring('content-length:'.length).trim();
        return int.tryParse(valueStr);
      }
    }
    return null;
  }
}
