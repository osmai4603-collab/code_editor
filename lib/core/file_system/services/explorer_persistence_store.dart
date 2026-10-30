import 'dart:convert';
import 'dart:io';

/// Stores the expanded tree paths and selected item for one workspace.
abstract interface class IExplorerPersistenceStore {
  Future<ExplorerPersistedState?> load(String workspacePath);

  Future<void> save(ExplorerPersistedState state);
}

/// JSON-backed explorer state store in the user's configuration directory.
class JsonExplorerPersistenceStore implements IExplorerPersistenceStore {
  final File? _stateFile;

  JsonExplorerPersistenceStore({File? stateFile})
    : _stateFile = stateFile ?? _defaultStateFile();

  static File? _defaultStateFile() {
    final home = Platform.isWindows
        ? Platform.environment['APPDATA']
        : Platform.environment['HOME'];
    if (home == null) return null;
    final path = Platform.isWindows
        ? _join(home, 'code_editor_explorer_state.json')
        : _join(_join(home, '.config'), 'code_editor_explorer_state.json');
    return File(path);
  }

  @override
  Future<ExplorerPersistedState?> load(String workspacePath) async {
    final file = _stateFile;
    if (file == null || !await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['workspace'] != workspacePath ||
        decoded['expanded'] is! List) {
      return null;
    }
    return ExplorerPersistedState(
      workspacePath: workspacePath,
      expandedPaths: (decoded['expanded'] as List).whereType<String>().toSet(),
      selectedPath: decoded['selected'] is String
          ? decoded['selected'] as String
          : null,
    );
  }

  @override
  Future<void> save(ExplorerPersistedState state) async {
    final file = _stateFile;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'workspace': state.workspacePath,
        'expanded': state.expandedPaths.toList(),
        'selected': state.selectedPath,
      }),
    );
  }

  static String _join(String directory, String name) =>
      directory.endsWith(Platform.pathSeparator)
      ? '$directory$name'
      : '$directory${Platform.pathSeparator}$name';
}

/// Persisted explorer state.
class ExplorerPersistedState {
  final String workspacePath;
  final Set<String> expandedPaths;
  final String? selectedPath;

  ExplorerPersistedState({
    required this.workspacePath,
    required Set<String> expandedPaths,
    this.selectedPath,
  }) : expandedPaths = Set.unmodifiable(expandedPaths);
}
