/// مواصفات وسجل الرموز الدلالية المرسلة من خادم LSP في تهيئة القدرات
class SemanticTokensLegend {
  final List<String> tokenTypes;
  final List<String> tokenModifiers;

  const SemanticTokensLegend({
    required this.tokenTypes,
    required this.tokenModifiers,
  });

  factory SemanticTokensLegend.fromJson(Map<String, dynamic> json) {
    return SemanticTokensLegend(
      tokenTypes: (json['tokenTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      tokenModifiers: (json['tokenModifiers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// الأسطورة الافتراضية وفق معيار LSP v3.16+
  static const defaultLegend = SemanticTokensLegend(
    tokenTypes: [
      'comment', 'keyword', 'string', 'number', 'regexp', 'operator',
      'namespace', 'type', 'struct', 'class', 'interface', 'enum',
      'typeParameter', 'function', 'method', 'decorator', 'macro',
      'variable', 'parameter', 'property', 'label', 'enumMember', 'event'
    ],
    tokenModifiers: [
      'declaration', 'definition', 'readonly', 'static', 'deprecated',
      'abstract', 'async', 'modification', 'documentation', 'defaultLibrary'
    ],
  );
}

/// استجابة الرموز الدلالية من السيرفر لطلب `textDocument/semanticTokens/full`
class SemanticTokens {
  final String? resultId;
  final List<int> data;

  const SemanticTokens({
    this.resultId,
    required this.data,
  });

  factory SemanticTokens.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    return SemanticTokens(
      resultId: json['resultId'] as String?,
      data: rawData.map((e) => (e as num).toInt()).toList(),
    );
  }

  /// فك تشفير المصفوفة الخماسية المضغوطة (Delta Decoded)
  List<DecodedSemanticToken> decode(SemanticTokensLegend legend) {
    final result = <DecodedSemanticToken>[];
    int currentLine = 0;
    int currentStartChar = 0;

    for (int i = 0; i + 4 < data.length; i += 5) {
      final deltaLine = data[i];
      final deltaStartChar = data[i + 1];
      final length = data[i + 2];
      final tokenTypeIndex = data[i + 3];
      final tokenModifiers = data[i + 4];

      if (deltaLine != 0) {
        currentLine += deltaLine;
        currentStartChar = deltaStartChar;
      } else {
        currentStartChar += deltaStartChar;
      }

      final typeStr = tokenTypeIndex < legend.tokenTypes.length
          ? legend.tokenTypes[tokenTypeIndex]
          : 'variable';

      result.add(DecodedSemanticToken(
        line: currentLine,
        startChar: currentStartChar,
        length: length,
        tokenType: typeStr,
        tokenModifiers: tokenModifiers,
      ));
    }

    return result;
  }
}

/// رمز دلالي مفكوك التشفير محدد بموضع السطر والعمود
class DecodedSemanticToken {
  final int line; // 0-indexed
  final int startChar;
  final int length;
  final String tokenType;
  final int tokenModifiers;

  const DecodedSemanticToken({
    required this.line,
    required this.startChar,
    required this.length,
    required this.tokenType,
    required this.tokenModifiers,
  });

  int get endChar => startChar + length;
}
