import 'package:flutter/material.dart';
import 'core/file_system/controllers/file_explorer_controller.dart';
import 'core/file_system/services/file_system_service.dart';
import 'core/file_system/services/file_watcher_service.dart';
import 'core/execution/execution_controller.dart';
import 'core/lsp/diagnostics/diagnostics_service.dart';
import 'core/lsp/registry/lsp_server_registry.dart';
import 'core/theme/editor_theme.dart';
import 'core/terminal/services/terminal_service.dart';
import 'core/terminal/services/terminal_scope.dart';
import 'layout/controllers/editor_controller.dart';
import 'layout/controllers/layout_controller.dart';
import 'layout/controllers/lsp_and_execution_scope.dart';
import 'layout/widgets/workbench_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CodeEditorApp());
}

class CodeEditorApp extends StatefulWidget {
  final bool autoStartLsp;
  final LspServerRegistry? lspRegistry;

  const CodeEditorApp({super.key, this.autoStartLsp = true, this.lspRegistry});

  @override
  State<CodeEditorApp> createState() => _CodeEditorAppState();
}

class _CodeEditorAppState extends State<CodeEditorApp> {
  late final WorkbenchLayoutController _layoutController;
  late final EditorDocumentsController _documentsController;
  late final DiagnosticsService _diagnosticsService;
  late final ExecutionController _executionController;
  late final TerminalService _terminalService;
  late final LspServerRegistry _lspRegistry;
  late final FileExplorerController _fileExplorerController;

  @override
  void initState() {
    super.initState();
    _layoutController = WorkbenchLayoutController();
    _documentsController = EditorDocumentsController();
    _diagnosticsService = DiagnosticsService();
    _executionController = ExecutionController();
    _terminalService = TerminalService();
    _fileExplorerController = FileExplorerController(
      fileService: FileSystemService(),
      watcherService: FileWatcherService(),
    );
    _lspRegistry =
        widget.lspRegistry ??
        LspServerRegistry(
          diagnosticsService: _diagnosticsService,
          autoStart: widget.autoStartLsp,
        );
  }

  @override
  void dispose() {
    _layoutController.dispose();
    _documentsController.dispose();
    _fileExplorerController.dispose();
    _executionController.dispose();
    _terminalService.dispose();
    _diagnosticsService.dispose();
    _lspRegistry.shutdownAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const editorTheme = EditorThemeData.darkModern;

    return EditorTheme(
      theme: editorTheme,
      child: DiagnosticsScope(
        notifier: _diagnosticsService,
        child: ExecutionScope(
          notifier: _executionController,
          child: LspRegistryScope(
            registry: _lspRegistry,
            child: WorkbenchLayoutScope(
              notifier: _layoutController,
              child: EditorDocumentsScope(
                notifier: _documentsController,
                child: FileExplorerScope(
                  notifier: _fileExplorerController,
                  child: TerminalScope(
                    notifier: _terminalService,
                    child: MaterialApp(
                    title: 'Modern Code Editor',
                    debugShowCheckedModeBanner: false,
                    theme: ThemeData.dark().copyWith(
                      scaffoldBackgroundColor: editorTheme.editorBackground,
                      canvasColor: editorTheme.sideBarBackground,
                      dividerColor: editorTheme.sideBarBorder,
                      colorScheme: ColorScheme.dark(
                        primary: editorTheme.accentColor,
                        surface: editorTheme.editorBackground,
                      ),
                    ),
                    home: const WorkbenchScaffold(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
