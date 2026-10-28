import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/file_system/controllers/file_explorer_controller.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/lsp/protocol/lsp_types.dart';
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
import 'widgets/hover_tooltip_widget.dart';

/// مساحة التحرير الرئيسية (Editor Part) وتشمل التبويبات وسطح الكود مع ميزات LSP
class EditorAreaWidget extends StatelessWidget {
  const EditorAreaWidget({super.key});

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

            if (activeTab != null) _buildBreadcrumbs(activeTab, theme),

            Expanded(
              child: activeTab != null
                  ? _CodeEditorSurface(
                      key: ValueKey(activeTab.id),
                      tabItem: activeTab,
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

  Widget _buildBreadcrumbs(EditorTabItem tab, EditorThemeData theme) {
    final segments = tab.path.split('/');
    return Container(
      height: EditorConstants.breadcrumbsHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: theme.editorBackground,
        border: Border(
          bottom: BorderSide(
            color: theme.tabBorder.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            Text(
              segments[i],
              style: TextStyle(
                color: i == segments.length - 1
                    ? theme.editorForeground
                    : theme.editorForeground.withValues(alpha: 0.5),
                fontSize: 11.5,
              ),
            ),
            if (i < segments.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: theme.editorForeground.withValues(alpha: 0.4),
                ),
              ),
          ],
        ],
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
  final String rootUri;
  final ValueChanged<String> onContentChanged;

  const _CodeEditorSurface({
    super.key,
    required this.tabItem,
    required this.rootUri,
    required this.onContentChanged,
  });

  @override
  State<_CodeEditorSurface> createState() => _CodeEditorSurfaceState();
}

class _CodeEditorSurfaceState extends State<_CodeEditorSurface> {
  late CodeEditorController _textController;
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  EditorLspExtension? _lspExtension;
  bool _isExtensionInitialized = false;

  @override
  void initState() {
    super.initState();
    _textController = CodeEditorController(
      text: widget.tabItem.content,
      filePath: widget.tabItem.path,
    );
    _textController.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      _lspExtension!.syncActiveTab(widget.tabItem, rootUri: widget.rootUri);
      _isExtensionInitialized = true;
    }
  }

  void _onTextChanged() {
    if (_textController.text != widget.tabItem.content) {
      widget.onContentChanged(_textController.text);
      _lspExtension?.onContentChanged(_textController.text);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _verticalScroll.dispose();
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

    final lines = _textController.text.split('\n');
    final lineCount = lines.isEmpty ? 1 : lines.length;

    // استخراج أسطر الأخطاء للملف الحالي
    final fileDiags = diagnosticsService.getForUri(widget.tabItem.path);
    final errorLines = fileDiags.map((d) => d.range.start.line).toSet();

    return ListenableBuilder(
      listenable: _lspExtension ?? ChangeNotifier(),
      builder: (context, _) {
        return Stack(
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
                                margin: const EdgeInsets.only(right: 4),
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
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CodeLens التفاعلي (Run | Debug) فوق main()
                        if (_lspExtension != null &&
                            _lspExtension!.hasMainFunction)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            child: CodeLensWidget(
                              onRun: () {
                                executionController.runFile(
                                  widget.tabItem.path,
                                );
                                if (!layoutController.state.isPanelVisible) {
                                  layoutController.togglePanel();
                                }
                                layoutController.selectPanelTab(
                                  PanelTab.output,
                                );
                              },
                            ),
                          ),

                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              color: theme.editorForeground,
                              fontSize: 13.5,
                              fontFamily: 'monospace',
                              height: 1.48,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // زر عائم مصغر لطلب الإكمال اليدوي (IntelliSense Trigger)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 70, bottom: 12),
                    child: FloatingActionButton.small(
                      backgroundColor: theme.tabActiveBackground,
                      foregroundColor: theme.accentColor,
                      tooltip: 'Autocomplete (IntelliSense)',
                      onPressed: () {
                        _lspExtension?.requestCompletions(
                          line: 0,
                          character: 0,
                          position: const Offset(120, 160),
                        );
                      },
                      child: const Icon(Icons.auto_awesome, size: 16),
                    ),
                  ),
                ),

                // الخريطة المصغرة للكود (Minimap placeholder)
                Container(
                  width: EditorConstants.minimapWidth,
                  decoration: BoxDecoration(
                    color: theme.editorBackground.withValues(alpha: 0.8),
                    border: Border(
                      left: BorderSide(
                        color: theme.tabBorder.withValues(alpha: 0.2),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: lineCount > 100 ? 100 : lineCount,
                    itemBuilder: (context, index) {
                      final hasError = errorLines.contains(index);

                      return Container(
                        height: 2.5,
                        margin: const EdgeInsets.symmetric(
                          vertical: 0.8,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasError
                              ? Colors.redAccent
                              : theme.editorForeground.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // قائمة الإكمال التلقائي العائمة (Completion Popup)
            if (_lspExtension != null && _lspExtension!.showCompletions)
              CompletionPopupWidget(
                items: _lspExtension!.completions,
                position:
                    _lspExtension!.popupPosition ?? const Offset(120, 150),
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
                    _lspExtension!.popupPosition ?? const Offset(120, 150),
                onDismiss: () => _lspExtension!.hideHover(),
              ),
          ],
        );
      },
    );
  }
}
