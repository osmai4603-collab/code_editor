import '../client/lsp_client.dart';

/// يدير حالة ومزامنة المستندات المفتوحة مع خادم LSP،
/// ويتابع أرقام الإصدارات (Document Versions) تلقائياً.
class LspDocumentTracker {
  final LspClient _client;
  final Map<String, int> _versions = {};
  final Map<String, String> _languageIds = {};

  LspDocumentTracker(this._client);

  /// فحص هل المستند مفتوح ومسجل حالياً
  bool isOpen(String uri) => _versions.containsKey(uri);

  /// الحصول على رقم إصدار المستند الحالي
  int getVersion(String uri) => _versions[uri] ?? 0;

  /// إشعار الخادم بفتح مستند جديد لأول مرة (textDocument/didOpen)
  void didOpen({
    required String uri,
    required String languageId,
    required String text,
    int initialVersion = 1,
  }) {
    _versions[uri] = initialVersion;
    _languageIds[uri] = languageId;

    _client.sendNotification('textDocument/didOpen', {
      'textDocument': {
        'uri': uri,
        'languageId': languageId,
        'version': initialVersion,
        'text': text,
      },
    });
  }

  /// إشعار الخادم بتعديل محتوى المستند (textDocument/didChange - Full Sync)
  int didChangeFull({
    required String uri,
    required String text,
  }) {
    final nextVersion = (_versions[uri] ?? 0) + 1;
    _versions[uri] = nextVersion;

    _client.sendNotification('textDocument/didChange', {
      'textDocument': {
        'uri': uri,
        'version': nextVersion,
      },
      'contentChanges': [
        {'text': text},
      ],
    });

    return nextVersion;
  }

  /// إشعار الخادم بحفظ المستند (textDocument/didSave)
  void didSave({
    required String uri,
    String? text,
  }) {
    _client.sendNotification('textDocument/didSave', {
      'textDocument': {
        'uri': uri,
      },
      'text': text,
    });
  }

  /// إشعار الخادم بإغلاق المستند وتحرير موارده (textDocument/didClose)
  void didClose(String uri) {
    if (!_versions.containsKey(uri)) return;

    _versions.remove(uri);
    _languageIds.remove(uri);

    _client.sendNotification('textDocument/didClose', {
      'textDocument': {
        'uri': uri,
      },
    });
  }

  /// مسح جميع المستندات عند إعادة ضبط العميل
  void clear() {
    _versions.clear();
    _languageIds.clear();
  }
}
