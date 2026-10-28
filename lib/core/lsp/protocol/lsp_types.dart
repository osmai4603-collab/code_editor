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

enum LspSymbolKind {
  file(1),
  module(2),
  namespace(3),
  package(4),
  classKind(5),
  method(6),
  property(7),
  field(8),
  constructor(9),
  enumKind(10),
  interfaceKind(11),
  function(12),
  variable(13),
  constant(14),
  string(15),
  number(16),
  boolean(17),
  array(18),
  object(19),
  key(20),
  nullKind(21),
  enumMember(22),
  struct(23),
  event(24),
  operatorKind(25),
  typeParameter(26),
  unknown(0);

  final int value;
  const LspSymbolKind(this.value);

  static LspSymbolKind fromValue(int value) {
    for (final kind in LspSymbolKind.values) {
      if (kind.value == value && kind != unknown) return kind;
    }
    return unknown;
  }
}

class LspDocumentSymbol {
  final String name;
  final LspSymbolKind kind;
  final LspRange range;
  final LspRange selectionRange;
  final String? detail;
  final String? containerName;
  final List<LspDocumentSymbol> children;

  const LspDocumentSymbol({
    required this.name,
    required this.kind,
    required this.range,
    required this.selectionRange,
    this.detail,
    this.containerName,
    this.children = const [],
  });

  static LspDocumentSymbol? tryParse(
    dynamic value, {
    String? documentText,
  }) {
    final json = _stringKeyedMap(value);
    if (json == null ||
        json['name'] is! String ||
        (json['name'] as String).isEmpty ||
        json['kind'] is! int ||
        json['range'] is! Map ||
        json['selectionRange'] is! Map) {
      return null;
    }

    final range = _parseValidRange(json['range'], documentText);
    final selectionRange = _parseValidRange(
      json['selectionRange'],
      documentText,
    );
    if (range == null ||
        selectionRange == null ||
        !_containsRange(range, selectionRange)) {
      return null;
    }

    final children = <LspDocumentSymbol>[];
    final rawChildren = json['children'];
    if (rawChildren is List) {
      for (final rawChild in rawChildren) {
        final child = tryParse(rawChild, documentText: documentText);
        if (child != null) children.add(child);
      }
    }

    return LspDocumentSymbol(
      name: json['name'] as String,
      kind: LspSymbolKind.fromValue(json['kind'] as int),
      range: range,
      selectionRange: selectionRange,
      detail: json['detail'] as String?,
      children: List.unmodifiable(children),
    );
  }
}

class LspSymbolInformation {
  final String name;
  final LspSymbolKind kind;
  final LspRange range;
  final String? containerName;

  const LspSymbolInformation({
    required this.name,
    required this.kind,
    required this.range,
    this.containerName,
  });

  static LspSymbolInformation? tryParse(
    dynamic value, {
    String? documentText,
  }) {
    final json = _stringKeyedMap(value);
    final location = _stringKeyedMap(json?['location']);
    if (json == null ||
        json['name'] is! String ||
        (json['name'] as String).isEmpty ||
        json['kind'] is! int ||
        location == null ||
        location['range'] is! Map) {
      return null;
    }
    final range = _parseValidRange(location['range'], documentText);
    if (range == null) return null;

    return LspSymbolInformation(
      name: json['name'] as String,
      kind: LspSymbolKind.fromValue(json['kind'] as int),
      range: range,
      containerName: json['containerName'] as String?,
    );
  }
}

class LspDocumentSymbolResponse {
  final bool isHierarchical;
  final List<LspDocumentSymbol> documentSymbols;
  final List<LspSymbolInformation> symbolInformation;

  const LspDocumentSymbolResponse._({
    required this.isHierarchical,
    required this.documentSymbols,
    required this.symbolInformation,
  });

  factory LspDocumentSymbolResponse.fromJson(
    dynamic value, {
    String? documentText,
  }) {
    if (value is! List) {
      return const LspDocumentSymbolResponse._(
        isHierarchical: true,
        documentSymbols: [],
        symbolInformation: [],
      );
    }

    final entries = value.whereType<Map>();
    final isHierarchical = entries.any(
      (entry) => entry.containsKey('selectionRange'),
    );
    if (isHierarchical) {
      final symbols = value
          .map(
            (entry) => LspDocumentSymbol.tryParse(
              entry,
              documentText: documentText,
            ),
          )
          .whereType<LspDocumentSymbol>()
          .toList();
      return LspDocumentSymbolResponse._(
        isHierarchical: true,
        documentSymbols: List.unmodifiable(symbols),
        symbolInformation: const [],
      );
    }

    final symbols = value
        .map(
          (entry) => LspSymbolInformation.tryParse(
            entry,
            documentText: documentText,
          ),
        )
        .whereType<LspSymbolInformation>()
        .toList();
    return LspDocumentSymbolResponse._(
      isHierarchical: false,
      documentSymbols: const [],
      symbolInformation: List.unmodifiable(symbols),
    );
  }
}

Map<String, dynamic>? _stringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

LspRange? _parseValidRange(dynamic value, String? documentText) {
  final json = _stringKeyedMap(value);
  if (json == null) return null;
  final start = _stringKeyedMap(json['start']);
  final end = _stringKeyedMap(json['end']);
  if (start == null ||
      end == null ||
      start['line'] is! int ||
      start['character'] is! int ||
      end['line'] is! int ||
      end['character'] is! int) {
    return null;
  }
  final range = LspRange.fromJson(json);
  if (range.start.line < 0 ||
      range.start.character < 0 ||
      range.end.line < 0 ||
      range.end.character < 0 ||
      _comparePositions(range.start, range.end) > 0) {
    return null;
  }
  if (documentText != null &&
      (!_positionFitsDocument(range.start, documentText) ||
          !_positionFitsDocument(range.end, documentText))) {
    return null;
  }
  return range;
}

bool _positionFitsDocument(LspPosition position, String text) {
  if (position.line < 0 || position.character < 0) return false;
  final lines = text.split('\n');
  return position.line < lines.length &&
      position.character <= lines[position.line].length;
}

bool _containsRange(LspRange outer, LspRange inner) =>
    _comparePositions(outer.start, inner.start) <= 0 &&
    _comparePositions(inner.end, outer.end) <= 0;

int _comparePositions(LspPosition left, LspPosition right) {
  final lineComparison = left.line.compareTo(right.line);
  return lineComparison != 0
      ? lineComparison
      : left.character.compareTo(right.character);
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
