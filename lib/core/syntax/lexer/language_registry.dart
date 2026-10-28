import 'language_syntax_definition.dart';
import 'rule_based_lexer.dart';

/// سجل مركزي عام للغات البرمجية وقواعدها النحوية دون أي ارتباط بمكتبات خارجية
class LanguageRegistry {
  static final LanguageRegistry _instance = LanguageRegistry._internal();
  factory LanguageRegistry() => _instance;

  final Map<String, LanguageSyntaxDefinition> _definitionsByExtension = {};
  final Map<String, LanguageSyntaxDefinition> _definitionsById = {};

  LanguageRegistry._internal() {
    _registerBuiltinLanguages();
  }

  /// تسجيل تعريف لغة جديد
  void register(LanguageSyntaxDefinition definition) {
    _definitionsById[definition.languageId.toLowerCase()] = definition;
    for (final ext in definition.extensions) {
      final cleanExt = ext.startsWith('.') ? ext.toLowerCase() : '.$ext'.toLowerCase();
      _definitionsByExtension[cleanExt] = definition;
    }
  }

  /// الحصول على المحلل النحوي المناسب لمسار الملف أو اسمه
  RuleBasedLexer getLexerForFile(String filePathOrName) {
    final dotIdx = filePathOrName.lastIndexOf('.');
    if (dotIdx != -1) {
      final ext = filePathOrName.substring(dotIdx).toLowerCase();
      final def = _definitionsByExtension[ext];
      if (def != null) return RuleBasedLexer(def);
    }
    return RuleBasedLexer(_fallbackDefinition);
  }

  /// الحصول على المحلل النحوي بناءً على معرّف اللغة
  RuleBasedLexer getLexerForLanguage(String languageId) {
    final def = _definitionsById[languageId.toLowerCase()] ?? _fallbackDefinition;
    return RuleBasedLexer(def);
  }

  static const LanguageSyntaxDefinition _fallbackDefinition = LanguageSyntaxDefinition(
    languageId: 'plaintext',
    extensions: ['.txt'],
  );

  void _registerBuiltinLanguages() {
    // 1. Dart (قواعد بيانات نصية بحتة دون أي استيراد لـ Dart SDK الداخلي)
    register(const LanguageSyntaxDefinition(
      languageId: 'dart',
      extensions: ['.dart'],
      controlKeywords: {
        'if', 'else', 'switch', 'case', 'default', 'for', 'while', 'do',
        'break', 'continue', 'return', 'try', 'catch', 'finally', 'throw',
        'rethrow', 'yield', 'await', 'async', 'sync', 'when',
      },
      keywords: {
        'class', 'extension', 'mixin', 'enum', 'abstract', 'interface',
        'base', 'sealed', 'final', 'const', 'var', 'late', 'required',
        'static', 'covariant', 'external', 'factory', 'get', 'set',
        'operator', 'part', 'of', 'import', 'export', 'library', 'show',
        'hide', 'as', 'is', 'in', 'typedef', 'with', 'implements', 'extends',
        'super', 'this', 'new', 'assert',
      },
      typeKeywords: {
        'void', 'int', 'double', 'num', 'bool', 'String', 'List', 'Map',
        'Set', 'Runes', 'Symbol', 'Object', 'Function', 'Future', 'Stream',
        'Iterable', 'Duration', 'DateTime', 'Uri', 'Pattern', 'RegExp',
        'dynamic', 'Never', 'Null', 'Record',
      },
      constantKeywords: {'true', 'false', 'null'},
      lineCommentPrefix: '//',
      docCommentPrefix: '///',
      blockCommentStart: '/*',
      blockCommentEnd: '*/',
    ));

    // 2. Python
    register(const LanguageSyntaxDefinition(
      languageId: 'python',
      extensions: ['.py', '.pyw'],
      controlKeywords: {
        'if', 'elif', 'else', 'for', 'while', 'break', 'continue', 'return',
        'yield', 'try', 'except', 'finally', 'raise', 'with', 'as', 'match', 'case',
      },
      keywords: {
        'def', 'class', 'import', 'from', 'lambda', 'global', 'nonlocal',
        'assert', 'pass', 'del', 'async', 'await', 'is', 'in', 'not', 'and', 'or',
      },
      typeKeywords: {
        'int', 'float', 'str', 'bool', 'list', 'dict', 'set', 'tuple',
        'bytes', 'object', 'type', 'NoneType',
      },
      constantKeywords: {'True', 'False', 'None'},
      lineCommentPrefix: '#',
    ));

    // 3. JavaScript / TypeScript
    register(const LanguageSyntaxDefinition(
      languageId: 'javascript',
      extensions: ['.js', '.jsx', '.ts', '.tsx', '.mjs'],
      controlKeywords: {
        'if', 'else', 'switch', 'case', 'default', 'for', 'while', 'do',
        'break', 'continue', 'return', 'try', 'catch', 'finally', 'throw',
        'yield', 'await',
      },
      keywords: {
        'function', 'class', 'const', 'let', 'var', 'new', 'delete',
        'typeof', 'instanceof', 'void', 'this', 'super', 'import', 'export',
        'from', 'as', 'default', 'async', 'extends', 'implements', 'interface',
        'type', 'enum', 'namespace', 'declare', 'abstract', 'readonly',
      },
      typeKeywords: {
        'string', 'number', 'boolean', 'any', 'unknown', 'never', 'void',
        'object', 'symbol', 'bigint', 'Array', 'Promise', 'Record',
      },
      constantKeywords: {'true', 'false', 'null', 'undefined', 'NaN', 'Infinity'},
      lineCommentPrefix: '//',
      docCommentPrefix: '/**',
      blockCommentStart: '/*',
      blockCommentEnd: '*/',
    ));

    // 4. JSON
    register(const LanguageSyntaxDefinition(
      languageId: 'json',
      extensions: ['.json', '.jsonc'],
      constantKeywords: {'true', 'false', 'null'},
      lineCommentPrefix: '//',
      blockCommentStart: '/*',
      blockCommentEnd: '*/',
    ));

    // 5. C / C++ / Rust / Go (عائلات لغات C-Style)
    register(const LanguageSyntaxDefinition(
      languageId: 'cpp',
      extensions: ['.c', '.cpp', '.h', '.hpp', '.cc', '.rs', '.go'],
      controlKeywords: {
        'if', 'else', 'switch', 'case', 'default', 'for', 'while', 'do',
        'break', 'continue', 'return', 'goto', 'fn', 'loop', 'match',
      },
      keywords: {
        'struct', 'class', 'union', 'enum', 'typedef', 'const', 'static',
        'extern', 'inline', 'virtual', 'override', 'public', 'private',
        'protected', 'template', 'typename', 'namespace', 'using', 'let',
        'mut', 'pub', 'impl', 'trait', 'package', 'func', 'type',
      },
      typeKeywords: {
        'void', 'int', 'char', 'float', 'double', 'short', 'long', 'signed',
        'unsigned', 'bool', 'size_t', 'auto', 'i32', 'i64', 'u32', 'u64',
        'f32', 'f64', 'string', 'uint', 'int32', 'int64',
      },
      constantKeywords: {'true', 'false', 'NULL', 'nullptr', 'nil'},
      lineCommentPrefix: '//',
      blockCommentStart: '/*',
      blockCommentEnd: '*/',
    ));
  }
}
