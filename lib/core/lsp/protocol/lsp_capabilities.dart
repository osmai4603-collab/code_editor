import 'lsp_types.dart';

/// قدرات عميل LSP المرسلة في رسالة المصافحة initialize
class LspClientCapabilities {
  static Map<String, dynamic> defaultCapabilities() {
    return {
      'textDocument': {
        'synchronization': {
          'dynamicRegistration': false,
          'willSave': false,
          'willSaveWaitUntil': false,
          'didSave': true,
        },
        'completion': {
          'dynamicRegistration': false,
          'completionItem': {
            'snippetSupport': true,
            'commitCharactersSupport': true,
            'documentationFormat': ['markdown', 'plaintext'],
            'deprecatedSupport': true,
            'preselectSupport': true,
          },
          'contextSupport': true,
        },
        'hover': {
          'dynamicRegistration': false,
          'contentFormat': ['markdown', 'plaintext'],
        },
        'documentSymbol': {
          'dynamicRegistration': false,
          'hierarchicalDocumentSymbolSupport': true,
        },
        'formatting': {'dynamicRegistration': false},
        'rangeFormatting': {'dynamicRegistration': false},
        'definition': {'dynamicRegistration': false, 'linkSupport': true},
        'references': {'dynamicRegistration': false},
        'publishDiagnostics': {
          'relatedInformation': true,
          'versionSupport': true,
        },
        'codeAction': {
          'dynamicRegistration': false,
          'codeActionLiteralSupport': {
            'codeActionKind': {
              'valueSet': [
                '',
                'quickfix',
                'refactor',
                'refactor.extract',
                'refactor.inline',
                'refactor.rewrite',
                'source',
                'source.organizeImports',
              ],
            },
          },
        },
        'codeLens': {'dynamicRegistration': false},
        'rename': {'dynamicRegistration': false, 'prepareSupport': true},
      },
      'workspace': {
        'applyEdit': true,
        'workspaceEdit': {'documentChanges': true},
        'configuration': false,
      },
    };
  }
}

/// قدرات خادم LSP المستخرجة من رد InitializeResult
class LspServerCapabilities {
  final TextDocumentSyncKind textDocumentSync;
  final bool hasCompletion;
  final bool hasHover;
  final bool hasDefinition;
  final bool hasReferences;
  final bool hasRename;
  final bool hasCodeAction;
  final bool hasCodeLens;
  final bool hasDocumentSymbol;
  final bool hasDocumentFormatting;
  final bool hasDocumentRangeFormatting;
  final bool hasDocumentOnTypeFormatting;
  final List<String> documentOnTypeFormattingTriggers;
  final Map<String, dynamic> raw;

  const LspServerCapabilities({
    required this.textDocumentSync,
    required this.hasCompletion,
    required this.hasHover,
    required this.hasDefinition,
    required this.hasReferences,
    required this.hasRename,
    required this.hasCodeAction,
    required this.hasCodeLens,
    required this.hasDocumentSymbol,
    required this.hasDocumentFormatting,
    required this.hasDocumentRangeFormatting,
    required this.hasDocumentOnTypeFormatting,
    required this.documentOnTypeFormattingTriggers,
    required this.raw,
  });

  factory LspServerCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LspServerCapabilities(
        textDocumentSync: TextDocumentSyncKind.full,
        hasCompletion: false,
        hasHover: false,
        hasDefinition: false,
        hasReferences: false,
        hasRename: false,
        hasCodeAction: false,
        hasCodeLens: false,
        hasDocumentSymbol: false,
        hasDocumentFormatting: false,
        hasDocumentRangeFormatting: false,
        hasDocumentOnTypeFormatting: false,
        documentOnTypeFormattingTriggers: const [],
        raw: {},
      );
    }

    // مزامنة المستندات قد تأتي كرقم أو كائن {change: 1, openClose: true}
    TextDocumentSyncKind syncKind = TextDocumentSyncKind.full;
    final syncRaw = json['textDocumentSync'];
    if (syncRaw is int) {
      syncKind = TextDocumentSyncKind.fromValue(syncRaw);
    } else if (syncRaw is Map<String, dynamic>) {
      final changeVal = syncRaw['change'];
      if (changeVal is int) {
        syncKind = TextDocumentSyncKind.fromValue(changeVal);
      }
    }

    final onTypeProvider = json['documentOnTypeFormattingProvider'];
    final onTypeTriggers = <String>[
      if (onTypeProvider is Map<String, dynamic> &&
          onTypeProvider['firstTriggerCharacter'] is String)
        onTypeProvider['firstTriggerCharacter'] as String,
      if (onTypeProvider is Map<String, dynamic> &&
          onTypeProvider['moreTriggerCharacter'] is List)
        ...(onTypeProvider['moreTriggerCharacter'] as List).whereType<String>(),
    ];

    return LspServerCapabilities(
      textDocumentSync: syncKind,
      hasCompletion: json.containsKey('completionProvider'),
      hasHover:
          json.containsKey('hoverProvider') && json['hoverProvider'] != false,
      hasDefinition:
          json.containsKey('definitionProvider') &&
          json['definitionProvider'] != false,
      hasReferences:
          json.containsKey('referencesProvider') &&
          json['referencesProvider'] != false,
      hasRename:
          json.containsKey('renameProvider') && json['renameProvider'] != false,
      hasCodeAction:
          json.containsKey('codeActionProvider') &&
          json['codeActionProvider'] != false,
      hasCodeLens:
          json.containsKey('codeLensProvider') &&
          json['codeLensProvider'] != false,
      hasDocumentSymbol:
          json['documentSymbolProvider'] == true ||
          json['documentSymbolProvider'] is Map,
      hasDocumentFormatting:
          json['documentFormattingProvider'] == true ||
          json['documentFormattingProvider'] is Map,
      hasDocumentRangeFormatting:
          json['documentRangeFormattingProvider'] == true ||
          json['documentRangeFormattingProvider'] is Map,
      hasDocumentOnTypeFormatting: onTypeTriggers.isNotEmpty,
      documentOnTypeFormattingTriggers: List.unmodifiable(onTypeTriggers),
      raw: json,
    );
  }
}
