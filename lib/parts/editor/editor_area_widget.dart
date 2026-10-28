import 'package:code_editor/parts/editor/scrollbar/editor_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/breadcrumbs/models/breadcrumb_symbol.dart';
import '../../core/breadcrumbs/services/breadcrumb_symbol_path_service.dart';
import '../../core/file_system/controllers/file_explorer_controller.dart';
import '../../core/file_system/services/editor_file_opener.dart';
import '../../core/file_system/services/file_system_service.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/lsp/protocol/lsp_types.dart';
import '../../core/statusbar/editor_status_controller.dart';
import '../../core/statusbar/status_bar_scope.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/editor_controller.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/controllers/lsp_and_execution_scope.dart';
import '../../layout/models/layout_state.dart';
import '../../models/editor_tab_item.dart';
import 'controllers/code_editor_controller.dart';
import 'controllers/editor_lsp_extension.dart';
import 'widgets/code_lens_widget.dart';
import 'widgets/completion_popup_widget.dart';
import 'breadcrumbs/breadcrumbs_bar.dart';
import 'widgets/hover_tooltip_widget.dart';

/// مساحة التحرير الرئيسية (Editor Part) وتشمل التبويبات وسطح الكود مع ميزات LSP
class EditorAreaWidget extends StatelessWidget {
  final EditorScrollbarVisibility scrollbarVisibility;

  const EditorAreaWidget({
    super.key,
    this.scrollbarVisibility = EditorScrollbarVisibility.auto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final editorController = EditorDocumentsScope.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final executionController = ExecutionScope.of(context);
    final workspacePath = FileExplorerScope.of(context).workspacePath;
    final activeTab = editorController.activeTab;

    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          editorController.saveCurrentTab().catchError((Object error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to save file: $error')),
              );
            }
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: theme.editorBackground,
        child: Column(
          children: [
            _buildTabsHeader(
              editorController,
              layoutController,
              executionController,
              theme,
            ),

            Expanded(
              child: activeTab != null
                  ? _CodeEditorSurface(
                      key: ValueKey(activeTab.id),
                      tabItem: activeTab,
                      scrollbarVisibility: scrollbarVisibility,
                      workspacePath: workspacePath,
                      rootUri: workspacePath == null
                          ? 'file:///'
                          : Uri.file(workspacePath).toString(),
                      onContentChanged: (newText) {
                        editorController.updateContent(activeTab.id, newText);
                      },
                    )
                  : _buildEmptyWatermark(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsHeader(
    EditorDocumentsController editorController,
    WorkbenchLayoutController layoutController,
    dynamic executionController,
    EditorThemeData theme,
  ) {
    final activeTab = editorController.activeTab;

    return Container(
      height: EditorConstants.tabHeight,
      decoration: BoxDecoration(
        color: theme.tabInactiveBackground,
        border: Border(bottom: BorderSide(color: theme.tabBorder, width: 1.0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: editorController.tabs.length,
              itemBuilder: (context, index) {
                final tab = editorController.tabs[index];
                final isActive = editorController.activeTabIndex == index;
                return _buildTabItem(tab, isActive, editorController, theme);
              },
            ),
          ),
          // أزرار سريعة في زاوية التبويبات (تشغيل الكود، تقسيم العرض)
          Row(
            children: [
              if (activeTab != null)
                Tooltip(
                  message: 'Run ${activeTab.title} (F5)',
                  child: InkWell(
                    onTap: () {
                      executionController.runFile(activeTab.path);
                      if (!layoutController.state.isPanelVisible) {
                        layoutController.togglePanel();
                      }
                      layoutController.selectPanelTab(PanelTab.output);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: Colors.greenAccent.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              _buildTabAction(
                Icons.vertical_split_outlined,
                'Split Editor Right',
                theme,
              ),
              _buildTabAction(Icons.more_horiz, 'More Actions...', theme),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    EditorTabItem tab,
    bool isActive,
    EditorDocumentsController controller,
    EditorThemeData theme,
  ) {
    return InkWell(
      onTap: () => controller.selectTab(tab.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? theme.tabActiveBackground
              : theme.tabInactiveBackground,
          border: Border(
            right: BorderSide(color: theme.tabBorder, width: 1.0),
            top: isActive
                ? BorderSide(color: theme.tabActiveBorderTop, width: 2.0)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getFileIcon(tab.title),
            const SizedBox(width: 8),
            Text(
              tab.title,
              style: TextStyle(
                color: isActive
                    ? theme.tabActiveForeground
                    : theme.tabInactiveForeground,
                fontSize: 12.5,
                fontStyle: tab.isPreview ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(width: 8),
            if (tab.isDirty)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              InkWell(
                onTap: () => controller.closeTab(tab.id),
                borderRadius: BorderRadius.circular(3),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: isActive
                        ? theme.tabActiveForeground
                        : theme.tabInactiveForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWatermark(EditorThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.code_rounded,
                  size: 64,
                  color: theme.editorForeground.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Editors Open',
                  style: TextStyle(
                    color: theme.editorForeground.withValues(alpha: 0.4),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a file from the explorer or press Ctrl+P to open file',
                  style: TextStyle(
                    color: theme.editorForeground.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabAction(IconData icon, String tooltip, EditorThemeData theme) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Icon(icon, size: 16, color: theme.tabInactiveForeground),
      ),
    );
  }

  Widget _getFileIcon(String filename) {
    if (filename.endsWith('.dart')) {
      return const Icon(Icons.flutter_dash, size: 14, color: Color(0xFF40C4FF));
    }
    return const Icon(
      Icons.insert_drive_file_outlined,
      size: 14,
      color: Color(0xFF9E9E9E),
    );
  }
}

/// سطح عرض وتحرير الأكواد الفعلي مع ترقيم السطور وربط ميزات LSP
class _CodeEditorSurface extends StatefulWidget {
  final EditorTabItem tabItem;
  final EditorScrollbarVisibility scrollbarVisibility;
  final String? workspacePath;
  final String rootUri;
  final ValueChanged<String> onContentChanged;

  const _CodeEditorSurface({
    super.key,
    required this.tabItem,
    required this.scrollbarVisibility,
    required this.workspacePath,
    required this.rootUri,
    required this.onContentChanged,
  });

  @override
  State<_CodeEditorSurface> createState() => _CodeEditorSurfaceState();
}

class _CodeEditorSurfaceState extends State<_CodeEditorSurface> {
  late CodeEditorController _textController;
  late final ValueNotifier<List<BreadcrumbSymbol>> _activeSymbolPath;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _editorVerticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  bool _isSynchronizingScroll = false;
  bool _scrollMetricsRefreshScheduled = false;
  EditorLspExtension? _lspExtension;
  bool _isExtensionInitialized = false;
  EditorStatusController? _editorStatusController;

  @override
  void initState() {
    super.initState();
    _textController = CodeEditorController(
      text: widget.tabItem.content,
      filePath: widget.tabItem.path,
    );
    _activeSymbolPath = ValueNotifier(const []);
    _textController.addListener(_onTextChanged);
    _verticalScroll.addListener(_syncEditorScroll);
    _editorVerticalScroll.addListener(_syncGutterScroll);
  }

  void _syncEditorScroll() =>
      _syncScrollOffset(_verticalScroll, _editorVerticalScroll);

  void _syncGutterScroll() =>
      _syncScrollOffset(_editorVerticalScroll, _verticalScroll);

  void _syncScrollOffset(ScrollController source, ScrollController target) {
    if (_isSynchronizingScroll ||
        !source.hasClients ||
        !target.hasClients ||
        !source.position.hasContentDimensions ||
        !target.position.hasContentDimensions) {
      return;
    }

    final sourceMax = source.position.maxScrollExtent;
    final targetMax = target.position.maxScrollExtent;
    final fraction = sourceMax == 0 ? 0.0 : source.offset / sourceMax;
    final targetOffset = (fraction * targetMax).clamp(0, targetMax).toDouble();
    if ((target.offset - targetOffset).abs() < 0.5) return;

    _isSynchronizingScroll = true;
    try {
      target.jumpTo(targetOffset);
    } finally {
      _isSynchronizingScroll = false;
    }
  }

  void _scheduleScrollbarMetricsRefresh() {
    if (_scrollMetricsRefreshScheduled) return;
    _scrollMetricsRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollMetricsRefreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _editorStatusController = EditorStatusScope.of(context);
    _updateEditorStatus();
    final diagnostics = DiagnosticsScope.of(context);
    _textController.diagnosticsService = diagnostics;

    if (!_isExtensionInitialized) {
      final registry = LspRegistryScope.of(context);
      final execution = ExecutionScope.of(context);

      _lspExtension = EditorLspExtension(
        registry: registry,
        diagnosticsService: diagnostics,
        executionController: execution,
      );
      _lspExtension!.onSemanticTokensUpdated = (tokens) {
        _textController.updateSemanticTokens(tokens);
      };
      _lspExtension!.addListener(_updateActiveSymbolPath);
      _lspExtension!.syncActiveTab(widget.tabItem, rootUri: widget.rootUri);
      _isExtensionInitialized = true;
    }
  }

  void _onTextChanged() {
    _updateEditorStatus();
    _updateActiveSymbolPath();
    if (_textController.text != widget.tabItem.content) {
      widget.onContentChanged(_textController.text);
      _lspExtension?.onContentChanged(_textController.text);
      setState(() {});
    }
  }

  void _updateEditorStatus() {
    _editorStatusController?.update(
      widget.tabItem.id,
      _textController.text,
      _textController.selection,
    );
  }

  void _updateActiveSymbolPath() {
    final symbols = _lspExtension?.documentSymbols ?? const [];
    final position = _positionAtOffset(
      _textController.text,
      _textController.selection.extentOffset,
    );
    final path = const BreadcrumbSymbolPathService().pathAtPosition(
      symbols,
      position,
    );
    final current = _activeSymbolPath.value;
    if (current.length == path.length &&
        List.generate(
          current.length,
          (index) => index,
        ).every((index) => identical(current[index], path[index]))) {
      return;
    }
    _activeSymbolPath.value = path;
  }

  LspPosition _positionAtOffset(String text, int offset) {
    final safeOffset = offset.clamp(0, text.length);
    final beforeCursor = text.substring(0, safeOffset);
    final line = '\n'.allMatches(beforeCursor).length;
    final lineStart = beforeCursor.lastIndexOf('\n') + 1;
    return LspPosition(line: line, character: safeOffset - lineStart);
  }

  int _offsetAtPosition(String text, LspPosition position) {
    final lines = text.split('\n');
    final line = position.line.clamp(0, lines.length - 1);
    var offset = 0;
    for (var index = 0; index < line; index++) {
      offset += lines[index].length + 1;
    }
    return offset + position.character.clamp(0, lines[line].length);
  }

  double _longestLineWidth(
    BuildContext context,
    List<String> lines,
    TextStyle style,
  ) {
    final longestLine = lines.reduce(
      (longest, line) => line.length > longest.length ? line : longest,
    );
    final painter = TextPainter(
      text: TextSpan(text: longestLine, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width + 2;
  }

  void _selectSymbol(BreadcrumbSymbol symbol) {
    final offset = _offsetAtPosition(
      _textController.text,
      symbol.selectionRange.start,
    );
    _textController.selection = TextSelection.collapsed(offset: offset);
    _editorFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _editorStatusController?.clearForTab(widget.tabItem.id);
    _textController.removeListener(_onTextChanged);
    _lspExtension?.removeListener(_updateActiveSymbolPath);
    _textController.dispose();
    _activeSymbolPath.dispose();
    _editorFocusNode.dispose();
    _verticalScroll.removeListener(_syncEditorScroll);
    _editorVerticalScroll.removeListener(_syncGutterScroll);
    _verticalScroll.dispose();
    _editorVerticalScroll.dispose();
    _horizontalScroll.dispose();
    _lspExtension?.dispose();
    super.dispose();
  }

  void _insertCompletion(CompletionItem item) {
    final text = _textController.text;
    final selection = _textController.selection;
    final insert = item.effectiveInsertText;

    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, insert);
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + insert.length,
        ),
      );
    } else {
      _textController.text = text + insert;
    }

    _lspExtension?.hideCompletions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final diagnosticsService = DiagnosticsScope.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final executionController = ExecutionScope.of(context);
    final documents = EditorDocumentsScope.of(context);
    final fileExplorer = FileExplorerScope.of(context);

    final lines = _textController.text.split('\n');
    final lineCount = lines.isEmpty ? 1 : lines.length;

    // استخراج أسطر الأخطاء للملف الحالي
    final fileDiags = diagnosticsService.getForUri(widget.tabItem.path);
    final errorLines = fileDiags.map((d) => d.range.start.line).toSet();

    return Column(
      children: [
        ListenableBuilder(
          listenable: _lspExtension!,
          builder: (context, _) =>
              ValueListenableBuilder<List<BreadcrumbSymbol>>(
                valueListenable: _activeSymbolPath,
                builder: (context, activeSymbols, _) => BreadcrumbsBar(
                  filePath: widget.tabItem.path,
                  workspacePath: widget.workspacePath,
                  listDirectory: fileExplorer.listDirectoryForNavigation,
                  openFile: (path) => EditorFileOpener(
                    FileSystemService(),
                  ).open(editor: documents, path: path),
                  symbols: _lspExtension!.documentSymbols,
                  activeSymbols: activeSymbols,
                  symbolsLoading: _lspExtension!.documentSymbolsLoading,
                  symbolsError: _lspExtension!.documentSymbolsError,
                  onSelectSymbol: _selectSymbol,
                ),
              ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _lspExtension ?? ChangeNotifier(),
            builder: (context, _) {
              return NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _scheduleScrollbarMetricsRefresh();
                  return false;
                },
                child: ScrollConfiguration(
                  behavior: const EditorScrollBehavior(),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // شريط أرقام السطور (Gutter) مع مؤشرات الأخطاء
                          Container(
                            width: EditorConstants.gutterWidth,
                            color: theme.editorGutterBackground,
                            child: ListView.builder(
                              controller: _verticalScroll,
                              physics: const ClampingScrollPhysics(),
                              itemCount: lineCount,
                              itemBuilder: (context, index) {
                                final hasError = errorLines.contains(index);

                                return Container(
                                  height: 20,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (hasError)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: hasError
                                              ? Colors.redAccent
                                              : theme.editorLineNumber,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          fontWeight: hasError
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // خط فاصل نحيف بين الأرقام ونصوص الكود
                          Container(
                            width: 1,
                            color: theme.tabBorder.withValues(alpha: 0.3),
                          ),

                          // مساحة كتابة الكود
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                top: 4.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // CodeLens التفاعلي (Run | Debug) فوق main()
                                  if (_lspExtension != null &&
                                      _lspExtension!.hasMainFunction)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 2,
                                      ),
                                      child: CodeLensWidget(
                                        onRun: () {
                                          executionController.runFile(
                                            widget.tabItem.path,
                                          );
                                          if (!layoutController
                                              .state
                                              .isPanelVisible) {
                                            layoutController.togglePanel();
                                          }
                                          layoutController.selectPanelTab(
                                            PanelTab.output,
                                          );
                                        },
                                      ),
                                    ),

                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final textStyle = TextStyle(
                                          color: theme.editorForeground,
                                          fontSize: 13.5,
                                          fontFamily: 'monospace',
                                          height: 1.48,
                                        );
                                        final contentWidth = _longestLineWidth(
                                          context,
                                          lines,
                                          textStyle,
                                        );
                                        return SingleChildScrollView(
                                          controller: _horizontalScroll,
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width:
                                                contentWidth >
                                                    constraints.maxWidth
                                                ? contentWidth
                                                : constraints.maxWidth,
                                            child: TextField(
                                              controller: _textController,
                                              focusNode: _editorFocusNode,
                                              scrollController:
                                                  _editorVerticalScroll,
                                              maxLines: null,
                                              expands: true,
                                              keyboardType:
                                                  TextInputType.multiline,
                                              style: textStyle,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // قائمة الإكمال التلقائي العائمة (Completion Popup)
                      if (_lspExtension != null &&
                          _lspExtension!.showCompletions)
                        CompletionPopupWidget(
                          items: _lspExtension!.completions,
                          position:
                              _lspExtension!.popupPosition ??
                              const Offset(120, 150),
                          onSelected: _insertCompletion,
                          onDismiss: () => _lspExtension!.hideCompletions(),
                        ),

                      // نافذة التوثيق العائمة (Hover Tooltip)
                      if (_lspExtension != null &&
                          _lspExtension!.showHover &&
                          _lspExtension!.hoverInfo != null)
                        HoverTooltipWidget(
                          hoverInfo: _lspExtension!.hoverInfo!,
                          position:
                              _lspExtension!.popupPosition ??
                              const Offset(120, 150),
                          onDismiss: () => _lspExtension!.hideHover(),
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 12,
                        width: 12,
                        child: EditorScrollbar(
                          key: const ValueKey('editor-vertical-scrollbar'),
                          axis: Axis.vertical,
                          controller: _editorVerticalScroll,
                          visibility: widget.scrollbarVisibility,
                        ),
                      ),
                      Positioned(
                        left: EditorConstants.gutterWidth + 9,
                        right: 0,
                        bottom: 0,
                        height: 12,
                        child: EditorScrollbar(
                          key: const ValueKey('editor-horizontal-scrollbar'),
                          axis: Axis.horizontal,
                          controller: _horizontalScroll,
                          visibility: widget.scrollbarVisibility,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
