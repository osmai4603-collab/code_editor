import 'dart:async';
import 'dart:math' as math;

import 'package:code_editor/core/editor/formatting/contracts/formatting_types.dart';
import 'package:code_editor/parts/editor/scrollbar/editor_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/editor/formatting/editor_formatting_preferences.dart';
import '../../core/editor/formatting/editor_formatting_preferences_scope.dart';
import '../../core/editor/formatting/editor_text_change.dart';
import '../../core/editor/formatting/models/stable_editor_scroll_state.dart';
import '../../core/editor/indentation/editor_indentation_options.dart';
import '../../core/editor/indentation/editor_input_formatter.dart';
import '../../core/editor/indentation/indentation_service.dart';
import '../../core/editor/indentation/whitespace_only_line_backspace.dart';
import '../../core/breadcrumbs/models/breadcrumb_symbol.dart';
import '../../core/breadcrumbs/services/breadcrumb_symbol_path_service.dart';
import '../../core/file_system/controllers/file_explorer_controller.dart';
import '../../core/file_system/services/file_system_service.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/lsp/protocol/lsp_types.dart';
import '../../core/statusbar/editor_status_controller.dart';
import '../../core/statusbar/models/status_bar_alignment.dart';
import '../../core/statusbar/models/status_bar_entry.dart';
import '../../core/statusbar/models/status_bar_entry_kind.dart';
import '../../core/statusbar/status_bar_scope.dart';
import '../../core/statusbar/status_bar_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/editor_theme.dart';
import '../settings/widgets/settings_editor_widget.dart';
import '../../layout/controllers/editor_controller.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/controllers/lsp_and_execution_scope.dart';
import '../../layout/services/editor_file_opener.dart';
import '../../layout/models/layout_state.dart';
import '../../models/editor_tab_item.dart';
import 'controllers/code_editor_controller.dart';
import 'controllers/editor_lsp_extension.dart';
import 'formatting/editor_formatting_controller.dart';
import 'widgets/code_lens_widget.dart';
import 'widgets/completion_popup_widget.dart';
import 'breadcrumbs/breadcrumbs_bar.dart';
import 'widgets/hover_tooltip_widget.dart';
import 'widgets/indentation_guides_painter.dart';
import 'widgets/diagnostics_overview_ruler.dart';
import 'widgets/editor_diagnostic_messages_painter.dart';

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
            event.logicalKey == LogicalKeyboardKey.comma &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          editorController.openSettingsTab();
          return KeyEventResult.handled;
        }
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
              child: activeTab?.type == EditorTabType.settingsEditor
                  ? SettingsEditorWidget(
                      key: ValueKey(activeTab!.id),
                      initialQuery: activeTab.settingsQuery,
                      initialCategory: activeTab.settingsCategory,
                    )
                  : activeTab != null
                  ? _CodeEditorSurface(
                      key: ValueKey(activeTab.id),
                      tabItem: activeTab,
                      navigationRequest: editorController.navigationRequest,
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
              if (activeTab?.type == EditorTabType.codeFile)
                Tooltip(
                  message: 'Run ${activeTab!.title} (F5)',
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
            tab.type == EditorTabType.settingsEditor
                ? const Icon(
                    Icons.settings_outlined,
                    size: 14,
                    color: Color(0xff9e9e9e),
                  )
                : _getFileIcon(tab.title),
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
  final EditorNavigationRequest? navigationRequest;
  final EditorScrollbarVisibility scrollbarVisibility;
  final String? workspacePath;
  final String rootUri;
  final ValueChanged<String> onContentChanged;

  const _CodeEditorSurface({
    super.key,
    required this.tabItem,
    required this.navigationRequest,
    required this.scrollbarVisibility,
    required this.workspacePath,
    required this.rootUri,
    required this.onContentChanged,
  });

  @override
  State<_CodeEditorSurface> createState() => _CodeEditorSurfaceState();
}

class _CodeEditorSurfaceState extends State<_CodeEditorSurface> {
  static const _indentationService = IndentationService();
  late CodeEditorController _textController;
  late EditorIndentationOptions _indentationOptions;
  late List<int> _indentationColumns;
  late String _indentationSourceText;
  late int _indentationSourceTabSize;
  late final ValueNotifier<List<BreadcrumbSymbol>> _activeSymbolPath;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _editorVerticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  bool _isSynchronizingScroll = false;
  bool _scrollMetricsRefreshScheduled = false;
  bool _editorStatusUpdateScheduled = false;
  bool _awaitingFormatSelectionChord = false;
  bool _pastePending = false;
  Timer? _pastePendingTimer;
  late String _lastUserInputText;
  int? _lastNavigationRequestId;
  EditorLspExtension? _lspExtension;
  EditorFormattingController? _formattingController;
  bool _isExtensionInitialized = false;
  EditorStatusController? _editorStatusController;
  StatusBarService? _statusBarService;
  StatusBarEntryHandle? _formatterStatusHandle;
  EditorDocumentsController? _documentsController;
  late EditorFormattingPreferencesController _formattingPreferencesController;
  EditorFormattingPreferences get _formattingPreferences =>
      _formattingPreferencesController.preferences.forLanguage(
        widget.tabItem.languageId,
      );

  @override
  void initState() {
    super.initState();
    _textController = CodeEditorController(
      text: widget.tabItem.content,
      filePath: widget.tabItem.path,
    );
    _indentationOptions =
        widget.tabItem.indentationOptions ??
        _indentationService.detect(widget.tabItem.content);
    _indentationSourceText = _textController.text;
    _lastUserInputText = _textController.text;
    _indentationSourceTabSize = _indentationOptions.tabSize;
    _indentationColumns = _buildIndentationColumns(
      _indentationSourceText,
      _indentationSourceTabSize,
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
    _textController.updateTheme(AppTheme.of(context).tokenTheme);
    _applyNavigationRequest();
    _editorStatusController = EditorStatusScope.of(context);
    _statusBarService = StatusBarScope.of(context);
    _formattingPreferencesController = EditorFormattingPreferencesScope.of(
      context,
    );
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
      _formattingController = EditorFormattingController(
        editorController: _textController,
        service: LspEditorFormattingService(_lspExtension!),
        preferences: () => _formattingPreferences,
        languageId: () => widget.tabItem.languageId,
        indentationOptions: () => _indentationOptions,
        isMounted: () => mounted,
        onError: _showEditorMessage,
        onFormatted: () => _lastUserInputText = _textController.text,
        workspacePath: widget.workspacePath,
        filePath: widget.tabItem.path,
        captureViewport: _captureStableScrollState,
        restoreViewport: _restoreStableScrollState,
        selectFormatter: _selectFormattingProvider,
        onFormatterConflict: _setFormatterConflictStatus,
      );
      _lspExtension!.onSemanticTokensUpdated = (tokens) {
        _textController.updateSemanticTokens(tokens);
      };
      _lspExtension!.addListener(_updateActiveSymbolPath);
      _lspExtension!.syncActiveTab(widget.tabItem, rootUri: widget.rootUri);
      _isExtensionInitialized = true;
    }
    _documentsController = EditorDocumentsScope.of(context);
    _documentsController!.setBeforeSaveHook(widget.tabItem.id, () async {
      await _formattingController?.formatOnSave();
    });
  }

  void _setFormatterConflictStatus(bool hasConflict) {
    if (!hasConflict) {
      _formatterStatusHandle?.dispose();
      _formatterStatusHandle = null;
      return;
    }

    final service = _statusBarService;
    if (service == null) return;
    final entry = StatusBarEntry(
      id: 'editor.formatter.${widget.tabItem.id}',
      name: 'Default formatter',
      text: 'Configure Formatter',
      alignment: StatusBarAlignment.right,
      priority: 10,
      tooltip: 'Choose a default formatter for this language',
      ariaLabel: 'Formatter conflict. Configure the default formatter.',
      kind: StatusBarEntryKind.warning,
      icon: Icons.warning_amber_rounded,
      onPressed: () => unawaited(_formatDocumentWith()),
    );
    if (_formatterStatusHandle == null) {
      _formatterStatusHandle = service.addEntry(entry);
    } else {
      _formatterStatusHandle!.update(entry);
    }
  }

  StableEditorScrollState? _captureStableScrollState() {
    final theme = EditorTheme.of(context);
    final lineHeight = _measureLineHeight(context, _editorTextStyle(theme));
    final cursorOffset = _textController.selection.extentOffset
        .clamp(0, _textController.text.length)
        .toInt();
    final cursorLine = '\n'
        .allMatches(_textController.text.substring(0, cursorOffset))
        .length;
    return StableEditorScrollState.capture(
      scrollController: _editorVerticalScroll,
      cursorLine: cursorLine,
      lineHeight: lineHeight,
    );
  }

  void _restoreStableScrollState(StableEditorScrollState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final theme = EditorTheme.of(context);
      final lineHeight = _measureLineHeight(context, _editorTextStyle(theme));
      final cursorOffset = _textController.selection.extentOffset
          .clamp(0, _textController.text.length)
          .toInt();
      final cursorLine = '\n'
          .allMatches(_textController.text.substring(0, cursorOffset))
          .length;
      state.restore(
        scrollController: _editorVerticalScroll,
        cursorLine: cursorLine,
        lineHeight: lineHeight,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _CodeEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationRequest?.id != widget.navigationRequest?.id ||
        oldWidget.tabItem.path != widget.tabItem.path) {
      _applyNavigationRequest();
    }
  }

  void _applyNavigationRequest() {
    final request = widget.navigationRequest;
    if (request == null ||
        request.id == _lastNavigationRequestId ||
        request.path != widget.tabItem.path) {
      return;
    }
    _lastNavigationRequestId = request.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final offset = _offsetAtPosition(
        _textController.text,
        LspPosition(line: request.line, character: request.character),
      );
      _textController.selection = TextSelection.collapsed(offset: offset);
      _editorFocusNode.requestFocus();
      if (!_editorVerticalScroll.hasClients ||
          !_editorVerticalScroll.position.hasContentDimensions) {
        return;
      }
      final theme = EditorTheme.of(context);
      final lineHeight = _measureLineHeight(context, _editorTextStyle(theme));
      final targetOffset =
          EditorConstants.editorTopInset + request.line * lineHeight;
      _editorVerticalScroll.jumpTo(
        targetOffset
            .clamp(0, _editorVerticalScroll.position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  void _onTextChanged() {
    _formattingController?.recordUserEdit();
    if (_indentationSourceText != _textController.text ||
        _indentationSourceTabSize != _indentationOptions.tabSize) {
      _indentationSourceText = _textController.text;
      _indentationSourceTabSize = _indentationOptions.tabSize;
      _indentationColumns = _buildIndentationColumns(
        _indentationSourceText,
        _indentationSourceTabSize,
      );
    }
    _updateEditorStatus();
    _updateActiveSymbolPath();
    if (_textController.text != widget.tabItem.content) {
      widget.onContentChanged(_textController.text);
      _lspExtension?.onContentChanged(_textController.text);
      setState(() {});
    }
  }

  List<int> _buildIndentationColumns(String text, int tabSize) => text
      .split('\n')
      .map((line) {
        final prefix = _indentationService.indentationOf(line);
        var columns = 0;
        for (final character in prefix.split('')) {
          columns = character == '\t'
              ? ((columns ~/ tabSize) + 1) * tabSize
              : columns + 1;
        }
        return columns;
      })
      .toList(growable: false);

  void _updateEditorStatus() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_editorStatusUpdateScheduled) return;
      _editorStatusUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _editorStatusUpdateScheduled = false;
        if (mounted) _updateEditorStatus();
      });
      return;
    }

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

  TextStyle _editorTextStyle(EditorThemeData theme) => TextStyle(
    color: theme.editorForeground,
    fontSize: EditorConstants.editorFontSize,
    fontFamily: 'JetBrains Mono',
    height: EditorConstants.editorLineHeight,
  );

  double _measureLineHeight(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.preferredLineHeight;
  }

  void _selectSymbol(BreadcrumbSymbol symbol) {
    final offset = _offsetAtPosition(
      _textController.text,
      symbol.selectionRange.start,
    );
    _textController.selection = TextSelection.collapsed(offset: offset);
    _editorFocusNode.requestFocus();
  }

  KeyEventResult _handleEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyS &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      unawaited(_saveCurrentDocument());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ &&
        (keyboard.isControlPressed || keyboard.isMetaPressed) &&
        !keyboard.isShiftPressed &&
        (_formattingController?.undoLastFormatting() ?? false)) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      _markPastePending();
      return KeyEventResult.ignored;
    }
    if (_awaitingFormatSelectionChord) {
      _awaitingFormatSelectionChord = false;
      if (event.logicalKey == LogicalKeyboardKey.keyF &&
          (keyboard.isControlPressed || keyboard.isMetaPressed)) {
        _formatDocument(selectionOnly: true);
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      _awaitingFormatSelectionChord = true;
      return KeyEventResult.handled;
    }
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed) {
      final value = _textController.value;
      final selection = _textController.selection;
      if (!selection.isValid || selection.end > value.text.length) {
        return KeyEventResult.ignored;
      }
      final formatter = EditorInputFormatter(
        options: _indentationOptions,
        languageId: widget.tabItem.languageId,
        onCharacterTyped: _handleCharacterTyped,
      );
      _textController.value = formatter.insertNewline(value, selection);
      _syncLastUserInputText();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed) {
      final joinedLine = removeWhitespaceOnlyLineOnBackspace(
        _textController.value,
        _textController.selection,
      );
      if (joinedLine != null) {
        _textController.value = joinedLine;
        _syncLastUserInputText();
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed) {
      _insertIndentation(keyboard.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        keyboard.isShiftPressed &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      _formatDocument();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        keyboard.isShiftPressed &&
        keyboard.isAltPressed) {
      _formatDocument();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertIndentation(bool outdent) {
    final text = _textController.text;
    final selection = _textController.selection;
    if (!selection.isValid) return;
    if (outdent) {
      final lineStart = selection.start <= 0
          ? 0
          : text.lastIndexOf('\n', selection.start - 1) + 1;
      final lineEndIndex = text.indexOf('\n', selection.end);
      final lineEnd = lineEndIndex < 0 ? text.length : lineEndIndex;
      final selectedLines = text.substring(lineStart, lineEnd);
      final lines = selectedLines.split('\n');
      final removedPerLine = <int>[];
      final updatedLines = <String>[];
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final remove = line.startsWith('\t')
            ? 1
            : line.startsWith(' ')
            ? _indentationOptions.indentSize.clamp(1, line.length).toInt()
            : 0;
        removedPerLine.add(remove);
        updatedLines.add(line.substring(remove));
      }
      final updated = text.replaceRange(
        lineStart,
        lineEnd,
        updatedLines.join('\n'),
      );
      int mapOutdentedOffset(int offset) {
        var oldLineStart = lineStart;
        var newLineStart = lineStart;
        for (var index = 0; index < lines.length; index++) {
          final oldLineEnd = oldLineStart + lines[index].length;
          if (offset <= oldLineEnd || index == lines.length - 1) {
            final column = (offset - oldLineStart)
                .clamp(0, lines[index].length)
                .toInt();
            final newColumn = (column - removedPerLine[index])
                .clamp(0, updatedLines[index].length)
                .toInt();
            return newLineStart + newColumn;
          }
          oldLineStart = oldLineEnd + 1;
          newLineStart += updatedLines[index].length + 1;
        }
        return updated.length;
      }

      _textController.value = TextEditingValue(
        text: updated,
        selection: TextSelection(
          baseOffset: mapOutdentedOffset(selection.baseOffset),
          extentOffset: mapOutdentedOffset(selection.extentOffset),
          isDirectional: selection.isDirectional,
        ),
      );
      _syncLastUserInputText();
      return;
    }

    final unit = _indentationOptions.indentUnit;
    if (!selection.isCollapsed) {
      final lineStart = selection.start <= 0
          ? 0
          : text.lastIndexOf('\n', selection.start - 1) + 1;
      final lineEndIndex = text.indexOf('\n', selection.end);
      final lineEnd = lineEndIndex < 0 ? text.length : lineEndIndex;
      final selectedLines = text.substring(lineStart, lineEnd);
      final lines = selectedLines.split('\n');
      final indented = lines.map((line) => '$unit$line').join('\n');
      final updated = text.replaceRange(lineStart, lineEnd, indented);
      int mapOffset(int offset) {
        final relative = (offset - lineStart).clamp(0, selectedLines.length);
        final precedingLines = '\n'
            .allMatches(selectedLines.substring(0, relative))
            .length;
        return offset + unit.length * (precedingLines + 1);
      }

      _textController.value = TextEditingValue(
        text: updated,
        selection: TextSelection(
          baseOffset: mapOffset(selection.baseOffset),
          extentOffset: mapOffset(selection.extentOffset),
          isDirectional: selection.isDirectional,
        ),
      );
      _syncLastUserInputText();
      return;
    }
    final updated = text.replaceRange(selection.start, selection.end, unit);
    _textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: selection.start + unit.length),
    );
    _syncLastUserInputText();
  }

  Future<void> _formatDocument({
    bool selectionOnly = false,
    LspRange? requestedRange,
    FormattingMode mode = FormattingMode.explicit,
  }) async {
    final controller = _formattingController;
    if (controller == null) {
      _showEditorMessage('No language server is available for this document');
      return;
    }
    await controller.formatDocument(
      selectionOnly: selectionOnly,
      requestedRange: requestedRange,
      mode: mode,
    );
  }

  Future<void> _formatOnType(String character, int offset) async {
    await _formattingController?.formatOnType(character, offset);
  }

  void _handleTextFieldChanged(String value) {
    final change = EditorTextChange.between(_lastUserInputText, value);
    _lastUserInputText = value;
    if (change == null) return;

    if (_pastePending) {
      _pastePending = false;
      _pastePendingTimer?.cancel();
      if (_formattingPreferences.formatOnPaste &&
          _lspExtension?.canFormatRange == true &&
          change.insertedText.isNotEmpty) {
        unawaited(
          _formatDocument(
            requestedRange: LspRange(
              start: _positionAtOffset(value, change.start),
              end: _positionAtOffset(
                value,
                change.start + change.insertedText.length,
              ),
            ),
            mode: FormattingMode.silent,
          ),
        );
      }
      return;
    }
  }

  void _handleCharacterTyped(String character) {
    final extension = _lspExtension;
    if (_pastePending || extension == null) return;
    scheduleMicrotask(() {
      if (!mounted ||
          _pastePending ||
          !_formattingPreferences.formatOnType ||
          !identical(_lspExtension, extension) ||
          !extension.formatOnTypeTriggers.contains(character)) {
        return;
      }
      unawaited(
        _formatOnType(character, _textController.selection.extentOffset),
      );
    });
  }

  void _markPastePending() {
    _pastePending = true;
    _pastePendingTimer?.cancel();
    _pastePendingTimer = Timer(const Duration(seconds: 1), () {
      _pastePending = false;
    });
  }

  Widget _buildTextFieldContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final buttonItems = editableTextState.contextMenuButtonItems.map((item) {
      if (item.type != ContextMenuButtonType.paste) return item;
      return ContextMenuButtonItem(
        type: item.type,
        onPressed: () {
          _markPastePending();
          item.onPressed?.call();
        },
      );
    }).toList();
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Future<void> _saveCurrentDocument() async {
    if (!mounted) return;
    try {
      await _documentsController?.saveTab(widget.tabItem.id);
    } catch (error) {
      _showEditorMessage('Unable to save file: $error');
    }
  }

  void _convertIndentation({required bool toSpaces, int? size}) {
    final current = _textController.value;
    final changesIndentSize = size != null;
    final converted = changesIndentSize && !_indentationOptions.insertSpaces
        ? current.text
        : _indentationService.convertIndentation(
            current.text,
            _indentationOptions,
            toSpaces: toSpaces,
            targetIndentSize: changesIndentSize ? size : null,
          );
    final oldLines = current.text.split('\n');
    final newLines = converted.split('\n');
    int mapOffset(int offset) {
      var oldLineStart = 0;
      var newLineStart = 0;
      for (var line = 0; line < oldLines.length; line++) {
        final oldLine = oldLines[line];
        final newLine = newLines[line];
        final oldIndent = _indentationService.indentationOf(oldLine).length;
        final newIndent = _indentationService.indentationOf(newLine).length;
        final oldLineEnd = oldLineStart + oldLine.length;
        if (offset <= oldLineEnd) {
          final column = offset - oldLineStart;
          final mappedColumn = column <= oldIndent
              ? column.clamp(0, newIndent).toInt()
              : column + newIndent - oldIndent;
          return newLineStart + mappedColumn;
        }
        oldLineStart = oldLineEnd + 1;
        newLineStart += newLine.length + 1;
      }
      return converted.length;
    }

    _textController.value = TextEditingValue(
      text: converted,
      selection: TextSelection(
        baseOffset: mapOffset(current.selection.baseOffset),
        extentOffset: mapOffset(current.selection.extentOffset),
        affinity: current.selection.affinity,
        isDirectional: current.selection.isDirectional,
      ),
    );
    _syncLastUserInputText();
    final options = _indentationOptions.copyWith(
      indentSize: size,
      insertSpaces: toSpaces,
      detectIndentation: false,
    );
    setState(() => _indentationOptions = options);
    EditorDocumentsScope.of(
      context,
    ).updateIndentationOptions(widget.tabItem.id, options);
  }

  void _showEditorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFormattingPreference(String preference) async {
    final current = _formattingPreferencesController.preferences;
    final effective = _formattingPreferences;
    final updatedOverride = EditorFormattingOverride(
      formatOnSave: preference == 'formatOnSave'
          ? !effective.formatOnSave
          : effective.formatOnSave,
      formatOnType: preference == 'formatOnType'
          ? !effective.formatOnType
          : effective.formatOnType,
      formatOnPaste: preference == 'formatOnPaste'
          ? !effective.formatOnPaste
          : effective.formatOnPaste,
      formatOnSaveMode: effective.formatOnSaveMode,
      defaultFormatter: effective.defaultFormatter,
    );
    final next = current.copyWith(
      languageOverrides: {
        ...current.languageOverrides,
        widget.tabItem.languageId: updatedOverride,
      },
    );
    try {
      await _formattingPreferencesController.update(next);
    } catch (error) {
      _showEditorMessage('Unable to save formatting preferences: $error');
    }
  }

  Future<void> _setFormattingSaveMode(FormatOnSaveMode mode) async {
    final current = _formattingPreferencesController.preferences;
    final effective = _formattingPreferences;
    try {
      await _formattingPreferencesController.update(
        current.copyWith(
          languageOverrides: {
            ...current.languageOverrides,
            widget.tabItem.languageId: EditorFormattingOverride(
              formatOnSave: effective.formatOnSave,
              formatOnType: effective.formatOnType,
              formatOnPaste: effective.formatOnPaste,
              formatOnSaveMode: mode,
              defaultFormatter: effective.defaultFormatter,
            ),
          },
        ),
      );
    } catch (error) {
      _showEditorMessage('Unable to save formatting preferences: $error');
    }
  }
  
  Future<void> _formatDocumentWith() async {
    final controller = _formattingController;
    if (controller == null) {
      _showEditorMessage('No formatter is available for this document');
      return;
    }
    final candidates = controller.availableFormatters(FormattingKind.file);
    if (candidates.isEmpty) {
      _showEditorMessage('No formatter is available for this document');
      return;
    }
    final selected = await _selectFormattingProvider(
      candidates,
      FormattingKind.file,
    );
    if (selected == null || !mounted) return;
    await _formatDocument();
  }

  Future<Object?> _selectFormattingProvider(
    List<Object> candidates,
    FormattingKind kind,
  ) async {
    final selected = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          kind == FormattingKind.file
              ? 'Choose Default Formatter'
              : 'Choose Range Formatter',
        ),
        children: candidates
            .map(
              (provider) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, provider),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.code),
                  title: Text(_formatterId(provider)),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return null;
    if (!await _storeDefaultFormatter(_formatterId(selected))) return null;
    return selected;
  }

  String _formatterId(Object provider) => switch (provider) {
    DocumentFormattingEditProvider() => provider.id,
    DocumentRangeFormattingEditProvider() => provider.id,
    _ => throw ArgumentError.value(
      provider,
      'provider',
      'Unsupported formatting provider',
    ),
  };

  Future<bool> _storeDefaultFormatter(String formatterId) async {
    final current = _formattingPreferencesController.preferences;
    final effective = _formattingPreferences;
    try {
      await _formattingPreferencesController.update(
        current.copyWith(
          languageOverrides: {
            ...current.languageOverrides,
            widget.tabItem.languageId: EditorFormattingOverride(
              formatOnSave: effective.formatOnSave,
              formatOnType: effective.formatOnType,
              formatOnPaste: effective.formatOnPaste,
              formatOnSaveMode: effective.formatOnSaveMode,
              defaultFormatter: formatterId,
            ),
          },
        ),
      );
      return true;
    } catch (error) {
      _showEditorMessage('Unable to set the default formatter: $error');
      return false;
    }
  }

  void _syncLastUserInputText() {
    _lastUserInputText = _textController.text;
  }

  @override
  void dispose() {
    _formatterStatusHandle?.dispose();
    _documentsController?.clearBeforeSaveHook(widget.tabItem.id);
    _editorStatusController?.clearForTab(widget.tabItem.id);
    _pastePendingTimer?.cancel();
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
    _formattingController?.dispose();
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
    _syncLastUserInputText();

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
    final diagnostics = diagnosticsService.getForUri(widget.tabItem.path);
    final diagnosticMessages =
        EditorDiagnosticMessagesPainter.messagesForDiagnostics(
          diagnostics,
          lineCount,
        );
    final lineSeverities = DiagnosticsOverviewRulerLayout.buildLineSeverities(
      diagnostics,
      lineCount,
    );
    final hasCodeLens = _lspExtension?.hasMainFunction == true;
    final textStyle = _editorTextStyle(theme);
    final textLineHeight = _measureLineHeight(context, textStyle);
    var documentExtent = lineCount * textLineHeight;
    if (_editorVerticalScroll.hasClients &&
        _editorVerticalScroll.position.hasContentDimensions) {
      final metrics = _editorVerticalScroll.position;
      documentExtent = math.max(
        documentExtent,
        metrics.maxScrollExtent + metrics.viewportDimension,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _lspExtension!,
                builder: (context, _) =>
                    ValueListenableBuilder<List<BreadcrumbSymbol>>(
                      valueListenable: _activeSymbolPath,
                      builder: (context, activeSymbols, _) => BreadcrumbsBar(
                        filePath: widget.tabItem.path,
                        workspacePath: widget.workspacePath,
                        listDirectory: fileExplorer.listDirectoryForNavigation,
                        openFile: (path) => EditorControllerFileOpener(
                          FileSystemService(),
                          documents,
                        ).open(path: path),
                        symbols: _lspExtension!.documentSymbols,
                        activeSymbols: activeSymbols,
                        symbolsLoading: _lspExtension!.documentSymbolsLoading,
                        symbolsError: _lspExtension!.documentSymbolsError,
                        onSelectSymbol: _selectSymbol,
                      ),
                    ),
              ),
            ),
            ListenableBuilder(
              listenable: _lspExtension!,
              builder: (context, _) => PopupMenuButton<String>(
                tooltip:
                    _lspExtension!.canFormatDocument ||
                        _lspExtension!.canFormatRange
                    ? 'Formatting and indentation'
                    : 'Formatting is not supported by this language server',
                icon: const Icon(Icons.format_indent_increase, size: 18),
                onSelected: (action) {
                  switch (action) {
                    case 'formatDocument':
                      _formatDocument();
                    case 'formatDocumentWith':
                      unawaited(_formatDocumentWith());
                    case 'formatSelection':
                      _formatDocument(selectionOnly: true);
                    case 'formatModifiedLines':
                      unawaited(_formattingController?.formatModifiedLines());
                    case 'formatModeFile':
                      unawaited(_setFormattingSaveMode(FormatOnSaveMode.file));
                    case 'formatModeModifications':
                      unawaited(
                        _setFormattingSaveMode(FormatOnSaveMode.modifications),
                      );
                    case 'formatModeModificationsIfAvailable':
                      unawaited(
                        _setFormattingSaveMode(
                          FormatOnSaveMode.modificationsIfAvailable,
                        ),
                      );
                    case 'formatOnSave':
                      unawaited(_toggleFormattingPreference('formatOnSave'));
                    case 'formatOnType':
                      unawaited(_toggleFormattingPreference('formatOnType'));
                    case 'formatOnPaste':
                      unawaited(_toggleFormattingPreference('formatOnPaste'));
                    case 'spaces':
                      _convertIndentation(toSpaces: true);
                    case 'tabs':
                      _convertIndentation(toSpaces: false);
                    case 'size2':
                      _convertIndentation(
                        toSpaces: _indentationOptions.insertSpaces,
                        size: 2,
                      );
                    case 'size4':
                      _convertIndentation(
                        toSpaces: _indentationOptions.insertSpaces,
                        size: 4,
                      );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'formatDocument',
                    enabled:
                        _formattingController?.supportsDocumentFormatting ==
                        true,
                    child: Text('Format Document'),
                  ),
                  PopupMenuItem(
                    value: 'formatDocumentWith',
                    enabled:
                        _formattingController?.supportsDocumentFormatting ==
                        true,
                    child: const Text('Format Document With...'),
                  ),
                  PopupMenuItem(
                    value: 'formatSelection',
                    enabled:
                        _formattingController?.supportsRangeFormatting == true,
                    child: Text('Format Selection'),
                  ),
                  PopupMenuItem(
                    value: 'formatModifiedLines',
                    enabled:
                        _formattingController?.supportsRangeFormatting == true,
                    child: const Text('Format Modified Lines'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'formatModeFile',
                    child: Text(
                      'Format on Save: File${_formattingPreferences.formatOnSaveMode == FormatOnSaveMode.file ? ' ✓' : ''}',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'formatModeModifications',
                    child: Text(
                      'Format on Save: Modifications${_formattingPreferences.formatOnSaveMode == FormatOnSaveMode.modifications ? ' ✓' : ''}',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'formatModeModificationsIfAvailable',
                    child: Text(
                      'Format on Save: Modifications if Available${_formattingPreferences.formatOnSaveMode == FormatOnSaveMode.modificationsIfAvailable ? ' ✓' : ''}',
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'formatOnSave',
                    enabled: _lspExtension?.canFormatDocument == true,
                    child: Row(
                      children: [
                        Icon(
                          _formattingPreferences.formatOnSave
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text('Format on Save'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'formatOnType',
                    enabled: _lspExtension?.canFormatOnType == true,
                    child: Row(
                      children: [
                        Icon(
                          _formattingPreferences.formatOnType
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text('Format on Type'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'formatOnPaste',
                    enabled: _lspExtension?.canFormatRange == true,
                    child: Row(
                      children: [
                        Icon(
                          _formattingPreferences.formatOnPaste
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text('Format on Paste'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'spaces',
                    child: Text('Convert Indentation to Spaces'),
                  ),
                  PopupMenuItem(
                    value: 'tabs',
                    child: Text(
                      'Convert Indentation to Tabs (Tab width: ${_indentationOptions.tabSize})',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'size2',
                    child: Text('Indent Size: 2'),
                  ),
                  const PopupMenuItem(
                    value: 'size4',
                    child: Text('Indent Size: 4'),
                  ),
                ],
              ),
            ),
          ],
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
                            child: Padding(
                              padding: EdgeInsets.only(
                                top:
                                    EditorConstants.editorTopInset +
                                    (hasCodeLens
                                        ? EditorConstants.codeLensHeight
                                        : 0),
                              ),
                              child: ListView.builder(
                                controller: _verticalScroll,
                                physics: const ClampingScrollPhysics(),
                                itemCount: lineCount,
                                itemExtent: textLineHeight,
                                itemBuilder: (context, index) {
                                  final severity = lineSeverities[index];
                                  final diagnosticColor = severity == null
                                      ? theme.editorLineNumber
                                      : theme.diagnosticColor(severity);

                                  return Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (severity != null)
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: diagnosticColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: diagnosticColor,
                                            fontSize: 12,
                                            fontFamily: 'JetBrains Mono',
                                            fontWeight: severity == null
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
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
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: EditorConstants.editorTopInset,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // CodeLens التفاعلي (Run | Debug) فوق main()
                                    if (hasCodeLens)
                                      SizedBox(
                                        height: EditorConstants.codeLensHeight,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
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
                                      ),

                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final reservedRightWidth =
                                              EditorConstants
                                                  .diagnosticsRulerWidth +
                                              EditorConstants
                                                  .diagnosticsRulerGap +
                                              EditorConstants
                                                  .verticalScrollbarWidth;
                                          final availableTextWidth =
                                              (constraints.maxWidth -
                                                      reservedRightWidth)
                                                  .clamp(0.0, double.infinity)
                                                  .toDouble();
                                          final measuredContentWidth =
                                              _longestLineWidth(
                                                context,
                                                lines,
                                                textStyle,
                                              );
                                          final diagnosticMessagesWidth =
                                              EditorDiagnosticMessagesPainter.requiredWidth(
                                                messages: diagnosticMessages,
                                                textStyle: textStyle.copyWith(
                                                  fontSize:
                                                      EditorConstants
                                                          .editorFontSize *
                                                      0.9,
                                                ),
                                                textDirection:
                                                    Directionality.of(context),
                                              );
                                          final contentWidth =
                                              math.max(
                                                measuredContentWidth +
                                                    diagnosticMessagesWidth,
                                                availableTextWidth,
                                              ) +
                                              reservedRightWidth;
                                          return SingleChildScrollView(
                                            controller: _horizontalScroll,
                                            scrollDirection: Axis.horizontal,
                                            child: SizedBox(
                                              width: contentWidth,
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  right: reservedRightWidth,
                                                ),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Positioned.fill(
                                                      child: AnimatedBuilder(
                                                        animation:
                                                            _editorVerticalScroll,
                                                        builder: (context, _) => IgnorePointer(
                                                          child: CustomPaint(
                                                            painter: IndentationGuidesPainter(
                                                              indentationColumns:
                                                                  _indentationColumns,
                                                              textStyle:
                                                                  textStyle,
                                                              options:
                                                                  _indentationOptions,
                                                              verticalOffset:
                                                                  _editorVerticalScroll
                                                                      .hasClients
                                                                  ? _editorVerticalScroll
                                                                        .offset
                                                                  : 0,
                                                              color: theme
                                                                  .editorLineNumber
                                                                  .withValues(
                                                                    alpha: 0.35,
                                                                  ),
                                                            ),
                                                            child:
                                                                const SizedBox.expand(),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Focus(
                                                      onKeyEvent:
                                                          _handleEditorKey,
                                                      child: TextField(
                                                        controller:
                                                            _textController,
                                                        focusNode:
                                                            _editorFocusNode,
                                                        inputFormatters: [
                                                          EditorInputFormatter(
                                                            options:
                                                                _indentationOptions,
                                                            languageId: widget
                                                                .tabItem
                                                                .languageId,
                                                            onCharacterTyped:
                                                                _handleCharacterTyped,
                                                          ),
                                                        ],
                                                        scrollController:
                                                            _editorVerticalScroll,
                                                        maxLines: null,
                                                        expands: true,
                                                        keyboardType:
                                                            TextInputType
                                                                .multiline,
                                                        style: textStyle,
                                                        onChanged:
                                                            _handleTextFieldChanged,
                                                        contextMenuBuilder:
                                                            _buildTextFieldContextMenu,
                                                        decoration:
                                                            const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets
                                                                      .zero,
                                                            ),
                                                      ),
                                                    ),
                                                    if (diagnosticMessages
                                                        .isNotEmpty)
                                                      Positioned.fill(
                                                        child: AnimatedBuilder(
                                                          animation:
                                                              _editorVerticalScroll,
                                                          builder: (context, _) {
                                                            final messageLabels =
                                                                diagnosticMessages
                                                                    .map(
                                                                      (
                                                                        message,
                                                                      ) =>
                                                                          'Line ${message.line + 1}: ${message.message}',
                                                                    )
                                                                    .join('. ');
                                                            return Semantics(
                                                              label:
                                                                  'Editor diagnostics: $messageLabels',
                                                              child: IgnorePointer(
                                                                child: CustomPaint(
                                                                  painter: EditorDiagnosticMessagesPainter(
                                                                    lines:
                                                                        lines,
                                                                    messages:
                                                                        diagnosticMessages,
                                                                    textStyle:
                                                                        textStyle,
                                                                    textDirection:
                                                                        Directionality.of(
                                                                          context,
                                                                        ),
                                                                    theme:
                                                                        theme,
                                                                    lineHeight:
                                                                        textLineHeight,
                                                                    verticalOffset:
                                                                        _editorVerticalScroll
                                                                            .hasClients
                                                                        ? _editorVerticalScroll
                                                                              .offset
                                                                        : 0,
                                                                  ),
                                                                  child:
                                                                      const SizedBox.expand(),
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
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                        top:
                            EditorConstants.editorTopInset +
                            (hasCodeLens ? EditorConstants.codeLensHeight : 0),
                        right: 0,
                        bottom: EditorConstants.horizontalScrollbarHeight,
                        width: EditorConstants.verticalScrollbarWidth,
                        child: EditorScrollbar(
                          key: const ValueKey('editor-vertical-scrollbar'),
                          axis: Axis.vertical,
                          controller: _editorVerticalScroll,
                          visibility: widget.scrollbarVisibility,
                        ),
                      ),
                      Positioned(
                        top:
                            EditorConstants.editorTopInset +
                            (hasCodeLens ? EditorConstants.codeLensHeight : 0),
                        right:
                            EditorConstants.verticalScrollbarWidth +
                            EditorConstants.diagnosticsRulerGap,
                        bottom: EditorConstants.horizontalScrollbarHeight,
                        width: EditorConstants.diagnosticsRulerWidth,
                        child: DiagnosticsOverviewRuler(
                          diagnostics: diagnostics,
                          lineCount: lineCount,
                          lineHeight: textLineHeight,
                          documentExtent: math.max(
                            documentExtent,
                            lineCount * textLineHeight,
                          ),
                        ),
                      ),
                      Positioned(
                        left: EditorConstants.gutterWidth + 9,
                        right: 0,
                        bottom: 0,
                        height: EditorConstants.horizontalScrollbarHeight,
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
