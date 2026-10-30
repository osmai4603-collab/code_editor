import 'package:code_editor/core/configuration/services/configuration_service.dart';
import 'package:code_editor/core/editor/formatting/editor_formatting_preferences.dart';
import 'package:code_editor/core/lsp/registry/lsp_server_registry.dart';
import 'package:code_editor/core/statusbar/status_bar_preferences_store.dart';
import 'package:code_editor/core/theme/app_theme_data.dart';
import 'package:code_editor/core/theme/theme_preferences_store.dart';
import 'dart:async';
import 'package:code_editor/core/configuration/contracts/configuration_service.dart';
import 'package:flutter/material.dart';
import 'core/configuration/adapters/configuration_preference_adapters.dart';
import 'core/configuration/registry/default_settings.dart';
import 'core/configuration/stores/configuration_store.dart';
import 'core/configuration/widgets/configuration_scope.dart';
import 'core/editor/formatting/editor_formatting_preferences_scope.dart';
import 'core/file_system/controllers/file_explorer_controller.dart';
import 'core/file_system/services/file_system_service.dart';
import 'core/file_system/services/file_watcher_service.dart';
import 'core/execution/execution_controller.dart';
import 'core/lsp/diagnostics/diagnostics_service.dart';
import 'core/output/output_service.dart';
import 'core/statusbar/contributions/diagnostics_status.dart';
import 'core/statusbar/contributions/editor_context_status.dart';
import 'core/statusbar/editor_status_controller.dart';
import 'core/statusbar/status_bar_scope.dart';
import 'core/statusbar/status_bar_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/editor_theme.dart';
import 'core/terminal/services/terminal_service.dart';
import 'core/terminal/services/terminal_scope.dart';
import 'layout/controllers/editor_controller.dart';
import 'layout/controllers/layout_controller.dart';
import 'layout/controllers/lsp_and_execution_scope.dart';
import 'layout/widgets/workbench_scaffold.dart';

class CodeEditorApp extends StatefulWidget {
  final bool autoStartLsp;
  final LspServerRegistry? lspRegistry;
  final StatusBarPreferencesStore? statusBarPreferencesStore;
  final EditorFormattingPreferencesStore? formattingPreferencesStore;
  final ThemePreferencesStore? themePreferencesStore;
  final AppThemeData? initialTheme;
  final ConfigurationService? configurationService;

  const CodeEditorApp({
    super.key,
    this.autoStartLsp = true,
    this.lspRegistry,
    this.statusBarPreferencesStore,
    this.formattingPreferencesStore,
    this.themePreferencesStore,
    this.initialTheme,
    this.configurationService,
  });

  @override
  State<CodeEditorApp> createState() => _CodeEditorAppState();
}



class _CodeEditorAppState extends State<CodeEditorApp> {
  late final WorkbenchLayoutController _layoutController;
  late final EditorDocumentsController _documentsController;
  late final DiagnosticsService _diagnosticsService;
  late final ExecutionController _executionController;
  late final OutputService _outputService;
  late final TerminalService _terminalService;
  late final StatusBarService _statusBarService;
  late final ThemePreferencesStore _themePreferencesStore;
  late final EditorFormattingPreferencesController
  _formattingPreferencesController;
  late final EditorStatusController _editorStatusController;
  late final LspServerRegistry _lspRegistry;
  late final FileExplorerController _fileExplorerController;
  late final ConfigurationService _configurationService;
  late final Future<void> _configurationInitialization;
  String? _lastWorkspacePath;
  late final Future<void> _statusBarInitialization;
  late final Future<void> _formattingPreferencesInitialization;
  late final Future<void> _themeInitialization;
  late final Future<void> _appInitialization;
  late final StreamSubscription<ConfigurationChangeEvent>
  _configurationChangeSubscription;
  bool _statusBarInitialized = false;
  bool _formattingInitialized = false;
  final List<void Function()> _disposeStatusBarContributions = [];
  bool _isDisposed = false;
  late AppThemeData _appTheme;

  @override
  void initState() {
    super.initState();
    _appTheme = widget.initialTheme ?? AppThemeData.darkModern;
    _layoutController = WorkbenchLayoutController();
    _documentsController = EditorDocumentsController();
    _diagnosticsService = DiagnosticsService();
    _executionController = ExecutionController();
    _outputService = OutputService(_executionController);
    _terminalService = TerminalService();
    _fileExplorerController = FileExplorerController(
      fileService: FileSystemService(),
      watcherService: FileWatcherService(),
    )..addListener(_onWorkspaceChanged);
    _configurationService =
        widget.configurationService ??
        ConfigurationService(
          registry: createDefaultConfigurationRegistry(),
          userStore: const SharedPreferencesConfigurationStore(),
          workspaceStore: WorkspaceJsonConfigurationStore(
            () => _fileExplorerController.workspacePath,
          ),
          memoryStore: InMemoryConfigurationStore(),
        );
    _configurationInitialization = _configurationService.initialize();
    _statusBarService = StatusBarService(
      preferencesStore:
          widget.statusBarPreferencesStore ??
          ConfigurationStatusBarPreferencesStore(
            configuration: _configurationService,
            legacyStore: SharedPreferencesStatusBarPreferencesStore(),
          ),
    );
    _themePreferencesStore =
        widget.themePreferencesStore ??
        ConfigurationThemePreferencesStore(
          configuration: _configurationService,
          legacyStore: SharedPreferencesThemePreferencesStore(),
        );
    _formattingPreferencesController = EditorFormattingPreferencesController(
      preferencesStore:
          widget.formattingPreferencesStore ??
          ConfigurationFormattingPreferencesStore(
            configuration: _configurationService,
            legacyStore: SharedPreferencesEditorFormattingPreferencesStore(),
          ),
    );
    _configurationChangeSubscription = _configurationService
        .onDidChangeConfiguration
        .listen(_onConfigurationChanged);
    _formattingPreferencesInitialization = _initializeFormattingPreferences();
    _themeInitialization = _initializeTheme();
    _editorStatusController = EditorStatusController();
    _statusBarInitialization = _initializeStatusBar();
    _appInitialization = Future.wait<void>([
      _configurationInitialization,
      _statusBarInitialization,
      _formattingPreferencesInitialization,
      _themeInitialization,
    ]).then((_) {});
    _lspRegistry =
        widget.lspRegistry ??
        LspServerRegistry(
          diagnosticsService: _diagnosticsService,
          autoStart: widget.autoStartLsp,
        );
  }

  Future<void> _initializeFormattingPreferences() async {
    await _configurationInitialization;
    await _formattingPreferencesController.initialize();
    _formattingInitialized = true;
  }

  void _onConfigurationChanged(ConfigurationChangeEvent event) {
    if (event.affects('workbench.colorTheme')) {
      final theme = AppThemeData.fromId(
        _configurationService.getValue<String>('workbench.colorTheme'),
      );
      if (theme != null && mounted && theme.id != _appTheme.id) {
        setState(() => _appTheme = theme);
      }
    }
    if (event.affects('workbench.statusBar.hiddenItems') &&
        _statusBarInitialized) {
      unawaited(_refreshStatusBarConfiguration());
    }
    if (_formattingInitialized &&
        event.changedKeys.any((key) => key.startsWith('editor.format'))) {
      unawaited(_refreshFormattingConfiguration());
    }
  }

  Future<void> _refreshStatusBarConfiguration() async {
    try {
      await _statusBarService.refreshPreferences();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'configuration',
          context: ErrorDescription('while applying status bar settings'),
        ),
      );
    }
  }

  Future<void> _refreshFormattingConfiguration() async {
    try {
      final store = _formattingPreferencesController;
      final preferencesStore = widget.formattingPreferencesStore == null
          ? ConfigurationFormattingPreferencesStore(
              configuration: _configurationService,
              legacyStore: SharedPreferencesEditorFormattingPreferencesStore(),
            )
          : null;
      if (preferencesStore == null) return;
      await store.update(await preferencesStore.read());
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'configuration',
          context: ErrorDescription('while applying editor formatting settings'),
        ),
      );
    }
  }

  Future<void> _initializeTheme() async {
    await _configurationInitialization;
    if (widget.initialTheme != null) return;
    final savedThemeId = await _themePreferencesStore.readThemeId();
    _appTheme = AppThemeData.fromId(savedThemeId) ?? AppThemeData.darkModern;
  }

  void _onWorkspaceChanged() {
    final workspacePath = _fileExplorerController.workspacePath;
    if (workspacePath == _lastWorkspacePath) return;
    _lastWorkspacePath = workspacePath;
    unawaited(_configurationInitialization.then((_) {
      return _configurationService.reloadWorkspace();
    }));
  }

  @override
  void didUpdateWidget(covariant CodeEditorApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTheme != oldWidget.initialTheme &&
        widget.initialTheme != null &&
        !identical(widget.initialTheme, _appTheme)) {
      _appTheme = widget.initialTheme!;
    }
  }

  Future<void> _selectTheme(AppThemeData theme) async {
    if (_appTheme.id == theme.id) return;
    await _themePreferencesStore.writeThemeId(theme.id);
    if (!mounted) return;
    setState(() => _appTheme = theme);
  }

  Future<void> _initializeStatusBar() async {
    await _configurationInitialization;
    await _statusBarService.initialize();
    _statusBarInitialized = true;
    if (_isDisposed) return;
    final editorContextContribution = EditorContextStatusContribution(
      documents: _documentsController,
      editorStatus: _editorStatusController,
      statusBar: _statusBarService,
    );
    final diagnosticsContribution = DiagnosticsStatusContribution(
      diagnostics: _diagnosticsService,
      layout: _layoutController,
      statusBar: _statusBarService,
    );
    _disposeStatusBarContributions
      ..add(editorContextContribution.dispose)
      ..add(diagnosticsContribution.dispose);
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final disposeContribution in _disposeStatusBarContributions) {
      disposeContribution();
    }
    _statusBarService.dispose();
    _configurationChangeSubscription.cancel();
    _formattingPreferencesController.dispose();
    _editorStatusController.dispose();
    _layoutController.dispose();
    _documentsController.dispose();
    _fileExplorerController.dispose();
    _configurationService.dispose();
    _outputService.dispose();
    _executionController.dispose();
    _terminalService.dispose();
    _diagnosticsService.dispose();
    _lspRegistry.shutdownAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return FutureBuilder<void>(
      future: _appInitialization,
      builder: (context, snapshot) {
        final appTheme = _appTheme;
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: SelectableText(
                    'Unable to initialize application preferences: ${snapshot.error}',
                  ),
                ),
              ),
            ),
          );
        }
        return ConfigurationScope(
          notifier: _configurationService,
          child: AppTheme(
          theme: appTheme,
          onThemeChanged: _selectTheme,
          child: EditorTheme(
            theme: appTheme.editorTheme,
            child: EditorFormattingPreferencesScope(
              notifier: _formattingPreferencesController,
              child: StatusBarScope(
                notifier: _statusBarService,
                child: EditorStatusScope(
                  notifier: _editorStatusController,
                  child: DiagnosticsScope(
                    notifier: _diagnosticsService,
                    child: ExecutionScope(
                      notifier: _executionController,
                      child: OutputScope(
                        notifier: _outputService,
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
                                    theme: appTheme.materialTheme,
                                    home: const WorkbenchScaffold(),
                                  ),
                                ),
                              ),
                            ),
                         ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
