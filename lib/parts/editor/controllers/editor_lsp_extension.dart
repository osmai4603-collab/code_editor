import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/breadcrumbs/models/breadcrumb_symbol.dart';
import '../../../core/execution/execution_controller.dart';
import '../../../core/lsp/client/lsp_client.dart';
import '../../../core/lsp/diagnostics/diagnostics_service.dart';
import '../../../core/lsp/protocol/lsp_semantic_tokens_types.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/lsp/registry/lsp_server_registry.dart';
import '../../../core/lsp/sync/lsp_change_debouncer.dart';
import '../../../core/lsp/sync/lsp_document_tracker.dart';
import '../../../models/editor_tab_item.dart';

/// وسيط الربط بين محرر الكود وعميل LSP ومحرك التنفيذ (Editor LSP Extension)
class EditorLspExtension extends ChangeNotifier {
  final LspServerRegistry registry;
  final DiagnosticsService diagnosticsService;
  final ExecutionController executionController;
  ValueChanged<List<DecodedSemanticToken>>? onSemanticTokensUpdated;

  LspClient? _activeClient;
  LspDocumentTracker? _tracker;
  late final LspChangeDebouncer _debouncer;

  EditorTabItem? _currentTab;
  List<CompletionItem> _completions = [];
  List<DecodedSemanticToken> _semanticTokens = [];
  HoverInfo? _hoverInfo;
  Offset? _popupPosition;
  bool _showCompletions = false;
  bool _showHover = false;
  bool _hasMainFunction = false;
  List<BreadcrumbSymbol> _documentSymbols = const [];
  bool _documentSymbolsLoading = false;
  String? _documentSymbolsError;
  int _contentVersion = 0;
  int _symbolRequestGeneration = 0;
  bool _disposed = false;
  String _documentText = '';

  EditorLspExtension({
    required this.registry,
    required this.diagnosticsService,
    required this.executionController,
  }) {
    _debouncer = LspChangeDebouncer(
      delay: const Duration(milliseconds: 200),
      onDebouncedChange: _onDebouncedDocumentChange,
    );
  }

  List<CompletionItem> get completions => _completions;
  List<DecodedSemanticToken> get semanticTokens => _semanticTokens;
  HoverInfo? get hoverInfo => _hoverInfo;
  Offset? get popupPosition => _popupPosition;
  bool get showCompletions => _showCompletions;
  bool get showHover => _showHover;
  bool get hasMainFunction => _hasMainFunction;
  List<BreadcrumbSymbol> get documentSymbols => _documentSymbols;
  bool get documentSymbolsLoading => _documentSymbolsLoading;
  String? get documentSymbolsError => _documentSymbolsError;

  /// مزامنة التبويب النشط في المحرر
  Future<void> syncActiveTab(
    EditorTabItem? tab, {
    String rootUri = 'file:///',
  }) async {
    if (tab == null) {
      _symbolRequestGeneration++;
      _currentTab = null;
      _documentText = '';
      _activeClient = null;
      _tracker = null;
      _documentSymbols = const [];
      _documentSymbolsLoading = false;
      _documentSymbolsError = null;
      _showCompletions = false;
      _showHover = false;
      _hasMainFunction = false;
      notifyListeners();
      return;
    }

    _currentTab = tab;
    _documentText = tab.content;
    _contentVersion++;
    _symbolRequestGeneration++;
    _documentSymbols = const [];
    _documentSymbolsLoading = false;
    _documentSymbolsError = null;
    _checkCodeLens(tab.content);

    final client = await registry.getClientForFile(tab.path, rootUri: rootUri);
    if (_disposed || _currentTab?.id != tab.id) return;
    _activeClient = client;

    if (client != null) {
      _tracker = LspDocumentTracker(client);
      final uri = _uriForPath(tab.path);

      if (!_tracker!.isOpen(uri)) {
        _tracker!.didOpen(
          uri: uri,
          languageId: tab.languageId,
          text: tab.content,
        );
      }
      unawaited(fetchSemanticTokens());
      unawaited(fetchDocumentSymbols());
    }

    notifyListeners();
  }

  /// إشعار بتعديل الكود
  void onContentChanged(String newText) {
    if (_currentTab == null) return;
    _contentVersion++;
    _documentText = newText;
    _symbolRequestGeneration++;
    _documentSymbols = const [];
    _documentSymbolsLoading = false;
    _documentSymbolsError = null;
    _checkCodeLens(newText);

    final uri = _uriForPath(_currentTab!.path);
    _debouncer.recordChange(uri, newText);
    notifyListeners();
  }

  void _onDebouncedDocumentChange(String uri, String text) {
    final contentVersion = _contentVersion;
    _tracker?.didChangeFull(uri: uri, text: text);
    unawaited(fetchSemanticTokens());
    unawaited(fetchDocumentSymbols(expectedContentVersion: contentVersion));
  }

  Future<void> fetchDocumentSymbols({int? expectedContentVersion}) async {
    final client = _activeClient;
    final tab = _currentTab;
    if (_disposed || client == null || tab == null) return;
    if (expectedContentVersion != null &&
        expectedContentVersion != _contentVersion) {
      return;
    }
    if (client.serverCapabilities?.hasDocumentSymbol != true) {
      _documentSymbols = const [];
      _documentSymbolsLoading = false;
      _documentSymbolsError = null;
      notifyListeners();
      return;
    }

    final generation = ++_symbolRequestGeneration;
    final contentVersion = _contentVersion;
    _documentSymbolsLoading = true;
    _documentSymbolsError = null;
    notifyListeners();
    try {
      final response = await client.sendRequest('textDocument/documentSymbol', {
        'textDocument': {'uri': _uriForPath(tab.path)},
      }, const Duration(seconds: 4));
      if (!_isCurrentSymbolRequest(generation, contentVersion, tab.id)) return;
      if (response.isError) {
        _documentSymbols = const [];
        _documentSymbolsLoading = false;
        if (response.error?.code != -32601) {
          _documentSymbolsError =
              response.error?.message ?? 'Document symbol request failed';
        }
        notifyListeners();
        return;
      }

      final parsed = LspDocumentSymbolResponse.fromJson(
        response.result,
        documentText: _documentText,
      );
      _documentSymbols = parsed.isHierarchical
          ? List.unmodifiable(parsed.documentSymbols.map(_fromDocumentSymbol))
          : List.unmodifiable(
              parsed.symbolInformation.map(
                (symbol) => BreadcrumbSymbol(
                  name: symbol.name,
                  kind: symbol.kind,
                  range: symbol.range,
                  selectionRange: symbol.range,
                  containerName: symbol.containerName,
                ),
              ),
            );
      _documentSymbolsLoading = false;
      _documentSymbolsError = null;
      notifyListeners();
    } catch (error) {
      if (!_isCurrentSymbolRequest(generation, contentVersion, tab.id)) return;
      _documentSymbols = const [];
      _documentSymbolsLoading = false;
      _documentSymbolsError = error.toString();
      notifyListeners();
    }
  }

  bool _isCurrentSymbolRequest(
    int generation,
    int contentVersion,
    String tabId,
  ) =>
      !_disposed &&
      generation == _symbolRequestGeneration &&
      contentVersion == _contentVersion &&
      _currentTab?.id == tabId;

  BreadcrumbSymbol _fromDocumentSymbol(LspDocumentSymbol symbol) =>
      BreadcrumbSymbol(
        name: symbol.name,
        kind: symbol.kind,
        range: symbol.range,
        selectionRange: symbol.selectionRange,
        containerName: symbol.containerName,
        children: List.unmodifiable(symbol.children.map(_fromDocumentSymbol)),
      );

  /// طلب الرموز الدلالية من خادم اللغة
  Future<void> fetchSemanticTokens() async {
    if (_activeClient == null || _currentTab == null) return;
    final uri = _uriForPath(_currentTab!.path);
    try {
      final response = await _activeClient!.sendRequest(
        'textDocument/semanticTokens/full',
        {
          'textDocument': {'uri': uri},
        },
        const Duration(seconds: 4),
      );
      if (response.isSuccess && response.result is Map<String, dynamic>) {
        final st = SemanticTokens.fromJson(
          response.result as Map<String, dynamic>,
        );
        final decoded = st.decode(SemanticTokensLegend.defaultLegend);
        _semanticTokens = decoded;
        onSemanticTokensUpdated?.call(decoded);
        notifyListeners();
      }
    } catch (_) {
      // تجاهل إذا كان الخادم لا يدعم الرموز الدلالية
    }
  }

  /// طلب الإكمال التلقائي عند موضع المؤشر
  Future<void> requestCompletions({
    required int line,
    required int character,
    required Offset position,
  }) async {
    if (_activeClient == null || _currentTab == null) {
      // إكمال تلقائي تجريبي ذكي للـ Fallback في حال عدم توفر خادم خارجي
      _completions = _buildFallbackCompletions();
      _popupPosition = position;
      _showCompletions = true;
      notifyListeners();
      return;
    }

    final uri = _uriForPath(_currentTab!.path);

    // إرسال didChange المعلق أولاً
    _debouncer.flush(uri);

    try {
      final response = await _activeClient!.sendRequest(
        'textDocument/completion',
        {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        },
        const Duration(seconds: 3),
      );

      if (response.isSuccess && response.result != null) {
        final list = CompletionList.fromJson(response.result);
        _completions = list.items;
      } else {
        _completions = _buildFallbackCompletions();
      }
    } catch (_) {
      _completions = _buildFallbackCompletions();
    }

    _popupPosition = position;
    _showCompletions = _completions.isNotEmpty;
    notifyListeners();
  }

  /// طلب التوثيق العائم (Hover)
  Future<void> requestHover({
    required int line,
    required int character,
    required Offset position,
    String? fallbackWord,
  }) async {
    if (_activeClient == null || _currentTab == null) {
      if (fallbackWord != null && fallbackWord.isNotEmpty) {
        _hoverInfo = HoverInfo(
          contents:
              '/// Symbol `$fallbackWord`\n\nPart of `${_currentTab?.title ?? "file"}`.',
        );
        _popupPosition = position;
        _showHover = true;
        notifyListeners();
      }
      return;
    }

    final uri = _uriForPath(_currentTab!.path);

    try {
      final response = await _activeClient!.sendRequest('textDocument/hover', {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character},
      }, const Duration(seconds: 3));

      if (response.isSuccess && response.result != null) {
        _hoverInfo = HoverInfo.fromJson(
          response.result as Map<String, dynamic>,
        );
        _popupPosition = position;
        _showHover = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  void hideCompletions() {
    if (_showCompletions) {
      _showCompletions = false;
      notifyListeners();
    }
  }

  void hideHover() {
    if (_showHover) {
      _showHover = false;
      notifyListeners();
    }
  }

  String _uriForPath(String path) =>
      path.startsWith('file://') ? path : Uri.file(path).toString();

  void _checkCodeLens(String content) {
    final hasMain =
        content.contains('void main()') || content.contains('main(');
    if (_hasMainFunction != hasMain) {
      _hasMainFunction = hasMain;
      notifyListeners();
    }
  }

  List<CompletionItem> _buildFallbackCompletions() {
    return const [
      CompletionItem(
        label: 'main',
        kind: CompletionItemKind.snippet,
        detail: 'void main() { ... }',
        documentation: 'Main application entry point',
        insertText: 'void main() {\n  \n}',
      ),
      CompletionItem(
        label: 'print',
        kind: CompletionItemKind.function,
        detail: 'void print(Object? object)',
        documentation:
            'Prints a string representation of the object to the console.',
        insertText: 'print()',
      ),
      CompletionItem(
        label: 'runApp',
        kind: CompletionItemKind.function,
        detail: 'void runApp(Widget app)',
        documentation: 'Inflate the given widget and attach it to the screen.',
        insertText: 'runApp()',
      ),
      CompletionItem(
        label: 'StatelessWidget',
        kind: CompletionItemKind.classKind,
        detail: 'class StatelessWidget',
        documentation: 'A widget that does not require mutable state.',
        insertText: 'StatelessWidget',
      ),
      CompletionItem(
        label: 'StatefulWidget',
        kind: CompletionItemKind.classKind,
        detail: 'class StatefulWidget',
        documentation: 'A widget that has mutable state.',
        insertText: 'StatefulWidget',
      ),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _symbolRequestGeneration++;
    _debouncer.dispose();
    super.dispose();
  }
}
