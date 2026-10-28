/// موضع حرف في المستند (0-indexed)
class LspPosition {
  final int line;
  final int character;

  const LspPosition({required this.line, required this.character});

  factory LspPosition.fromJson(Map<String, dynamic> json) {
    return LspPosition(
      line: json['line'] as int? ?? 0,
      character: json['character'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'line': line,
        'character': character,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LspPosition &&
          runtimeType == other.runtimeType &&
          line == other.line &&
          character == other.character;

  @override
  int get hashCode => Object.hash(line, character);

  @override
  String toString() => '$line:$character';
}

/// نطاق نصي بين موضع بداية وموضع نهاية
class LspRange {
  final LspPosition start;
  final LspPosition end;

  const LspRange({required this.start, required this.end});

  factory LspRange.fromJson(Map<String, dynamic> json) {
    return LspRange(
      start: LspPosition.fromJson(json['start'] as Map<String, dynamic>? ?? {}),
      end: LspPosition.fromJson(json['end'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start.toJson(),
        'end': end.toJson(),
      };

  @override
  String toString() => 'Range($start -> $end)';
}

/// موقع في ملف معين مع النطاق
class LspLocation {
  final String uri;
  final LspRange range;

  const LspLocation({required this.uri, required this.range});

  factory LspLocation.fromJson(Map<String, dynamic> json) {
    return LspLocation(
      uri: json['uri'] as String? ?? '',
      range: LspRange.fromJson(json['range'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'range': range.toJson(),
      };

  @override
  String toString() => 'Location($uri, $range)';
}

/// درجة خطورة المشكلة / التشخيص
enum DiagnosticSeverity {
  error(1),
  warning(2),
  information(3),
  hint(4);

  final int value;
  const DiagnosticSeverity(this.value);

  static DiagnosticSeverity fromValue(int? value) {
    switch (value) {
      case 1:
        return DiagnosticSeverity.error;
      case 2:
        return DiagnosticSeverity.warning;
      case 3:
        return DiagnosticSeverity.information;
      case 4:
        return DiagnosticSeverity.hint;
      default:
        return DiagnosticSeverity.error;
    }
  }
}

/// عنصر تشخيص أو خطأ برمجي مستلم من الخادم
class DiagnosticItem {
  final String uri;
  final LspRange range;
  final DiagnosticSeverity severity;
  final String message;
  final String? source;
  final dynamic code;

  const DiagnosticItem({
    required this.uri,
    required this.range,
    required this.severity,
    required this.message,
    this.source,
    this.code,
  });

  factory DiagnosticItem.fromJson(String uri, Map<String, dynamic> json) {
    return DiagnosticItem(
      uri: uri,
      range: LspRange.fromJson(json['range'] as Map<String, dynamic>? ?? {}),
      severity: DiagnosticSeverity.fromValue(json['severity'] as int?),
      message: json['message'] as String? ?? '',
      source: json['source'] as String?,
      code: json['code'],
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'range': range.toJson(),
        'severity': severity.value,
        'message': message,
        if (source != null) 'source': source,
        if (code != null) 'code': code,
      };

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $uri (${range.start}): $message';
}

/// نوع عنصر الإكمال التلقائي
enum CompletionItemKind {
  text(1),
  method(2),
  function(3),
  constructor(4),
  field(5),
  variable(6),
  classKind(7),
  interfaceKind(8),
  module(9),
  property(10),
  unit(11),
  valueKind(12),
  enumKind(13),
  keyword(14),
  snippet(15),
  color(16),
  file(17),
  reference(18),
  folder(19),
  enumMember(20),
  constant(21),
  struct(22),
  event(23),
  operatorKind(24),
  typeParameter(25);

  final int value;
  const CompletionItemKind(this.value);

  static CompletionItemKind fromValue(int? value) {
    if (value == null) return CompletionItemKind.text;
    for (final kind in CompletionItemKind.values) {
      if (kind.value == value) return kind;
    }
    return CompletionItemKind.text;
  }
}

/// عنصر مقترح للإكمال التلقائي
class CompletionItem {
  final String label;
  final CompletionItemKind kind;
  final String? detail;
  final String? documentation;
  final String? insertText;
  final String? filterText;
  final String? sortText;
  final Map<String, dynamic>? textEdit;

  const CompletionItem({
    required this.label,
    this.kind = CompletionItemKind.text,
    this.detail,
    this.documentation,
    this.insertText,
    this.filterText,
    this.sortText,
    this.textEdit,
  });

  /// النص الفعلي الذي يتم إدراجه في المحرر
  String get effectiveInsertText {
    if (insertText != null && insertText!.isNotEmpty) {
      return insertText!;
    }
    if (textEdit != null && textEdit!['newText'] is String) {
      return textEdit!['newText'] as String;
    }
    return label;
  }

  factory CompletionItem.fromJson(Map<String, dynamic> json) {
    String? docs;
    final rawDocs = json['documentation'];
    if (rawDocs is String) {
      docs = rawDocs;
    } else if (rawDocs is Map && rawDocs['value'] is String) {
      docs = rawDocs['value'] as String;
    }

    return CompletionItem(
      label: json['label'] as String? ?? '',
      kind: CompletionItemKind.fromValue(json['kind'] as int?),
      detail: json['detail'] as String?,
      documentation: docs,
      insertText: json['insertText'] as String?,
      filterText: json['filterText'] as String?,
      sortText: json['sortText'] as String?,
      textEdit: json['textEdit'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'kind': kind.value,
        if (detail != null) 'detail': detail,
        if (documentation != null) 'documentation': documentation,
        if (insertText != null) 'insertText': insertText,
        if (filterText != null) 'filterText': filterText,
        if (sortText != null) 'sortText': sortText,
        if (textEdit != null) 'textEdit': textEdit,
      };
}

/// قائمة نتائج الإكمال
class CompletionList {
  final bool isIncomplete;
  final List<CompletionItem> items;

  const CompletionList({required this.isIncomplete, required this.items});

  factory CompletionList.fromJson(dynamic json) {
    if (json is List) {
      return CompletionList(
        isIncomplete: false,
        items: json
            .whereType<Map<String, dynamic>>()
            .map(CompletionItem.fromJson)
            .toList(),
      );
    } else if (json is Map<String, dynamic>) {
      final rawItems = json['items'] as List? ?? [];
      return CompletionList(
        isIncomplete: json['isIncomplete'] as bool? ?? false,
        items: rawItems
            .whereType<Map<String, dynamic>>()
            .map(CompletionItem.fromJson)
            .toList(),
      );
    }
    return const CompletionList(isIncomplete: false, items: []);
  }
}

/// معلومات التوثيق العائمة (Hover)
class HoverInfo {
  final String contents;
  final LspRange? range;

  const HoverInfo({required this.contents, this.range});

  factory HoverInfo.fromJson(Map<String, dynamic> json) {
    final rawContents = json['contents'];
    String parsed = '';

    if (rawContents is String) {
      parsed = rawContents;
    } else if (rawContents is List) {
      parsed = rawContents.map((c) {
        if (c is String) return c;
        if (c is Map && c['value'] is String) return c['value'] as String;
        return '';
      }).join('\n\n');
    } else if (rawContents is Map) {
      if (rawContents['value'] is String) {
        parsed = rawContents['value'] as String;
      }
    }

    final rangeJson = json['range'] as Map<String, dynamic>?;
    return HoverInfo(
      contents: parsed,
      range: rangeJson != null ? LspRange.fromJson(rangeJson) : null,
    );
  }
}

/// نوع مزامنة المستندات المدعوم
enum TextDocumentSyncKind {
  none(0),
  full(1),
  incremental(2);

  final int value;
  const TextDocumentSyncKind(this.value);

  static TextDocumentSyncKind fromValue(int? value) {
    switch (value) {
      case 0:
        return TextDocumentSyncKind.none;
      case 1:
        return TextDocumentSyncKind.full;
      case 2:
        return TextDocumentSyncKind.incremental;
      default:
        return TextDocumentSyncKind.full;
    }
  }
}

/// عنصر CodeLens (مثل أزرار Run / Debug فوق الدوال)
class CodeLensItem {
  final LspRange range;
  final String? title;
  final String? command;
  final List<dynamic>? arguments;

  const CodeLensItem({
    required this.range,
    this.title,
    this.command,
    this.arguments,
  });

  factory CodeLensItem.fromJson(Map<String, dynamic> json) {
    final cmd = json['command'] as Map<String, dynamic>?;
    return CodeLensItem(
      range: LspRange.fromJson(json['range'] as Map<String, dynamic>? ?? {}),
      title: cmd?['title'] as String?,
      command: cmd?['command'] as String?,
      arguments: cmd?['arguments'] as List<dynamic>?,
    );
  }
}

/// عنصر إصلاح سريع (CodeAction)
class CodeActionItem {
  final String title;
  final String? kind;
  final Map<String, dynamic>? edit;
  final Map<String, dynamic>? command;

  const CodeActionItem({
    required this.title,
    this.kind,
    this.edit,
    this.command,
  });

  factory CodeActionItem.fromJson(Map<String, dynamic> json) {
    return CodeActionItem(
      title: json['title'] as String? ?? '',
      kind: json['kind'] as String?,
      edit: json['edit'] as Map<String, dynamic>?,
      command: json['command'] as Map<String, dynamic>?,
    );
  }
}
