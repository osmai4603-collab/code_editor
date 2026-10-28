import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/file_tree_item.dart';
import '../models/sort_config.dart';
import '../services/file_system_service.dart';
import '../services/file_watcher_service.dart';

enum ExplorerSearchMode { filter, highlight }

class FileExplorerController extends ChangeNotifier {
  final FileSystemService _fileService;
  final FileWatcherService _watcherService;
  final bool persistState;
  late final StreamSubscription<List<FileChangeEvent>> _watcherSubscription;

  FileTreeItem? _root;
  String? _workspacePath;
  final Set<String> _expandedPaths = {};
  String? _selectedPath;
  final Set<String> _multiSelection = {};
  SortConfig _sortConfig = const SortConfig.defaultConfig();
  bool _isLoading = false;
  String? _error;
  String? _editingPath;
  String? _creatingInPath;
  bool _creatingIsDirectory = false;
  List<String>? _clipboardPaths;
  bool _clipboardIsCut = false;
  bool _showHiddenFiles = false;
  String _searchQuery = '';
  ExplorerSearchMode _searchMode = ExplorerSearchMode.filter;
  Set<String> _searchResultPaths = {};
  Set<String> _searchAncestorPaths = {};
  Timer? _searchDebouncer;
  Timer? _gitStatusDebouncer;
  int _searchGeneration = 0;
  int _gitStatusGeneration = 0;
  bool _isSearching = false;
  Map<String, String> _gitStatuses = {};
  Timer? _refreshDebouncer;
  List<FileTreeItem>? _cachedVisibleItems;
  bool _isDirty = true;
  bool _disposed = false;

  FileExplorerController({
    required this._fileService,
    required this._watcherService,
    this.persistState = true,
  }) {
    _watcherSubscription = _watcherService.changes.listen(
      _onFileChanged,
      onError: (Object error, StackTrace stackTrace) {
        _error = 'File watcher failed: $error';
        notifyListeners();
      },
    );
  }

  void _removeSelectionForPath(String path) {
    bool isDeleted(String candidate) =>
        candidate == path ||
        candidate.startsWith('$path${Platform.pathSeparator}');
    _multiSelection.removeWhere(isDeleted);
    if (_selectedPath != null && isDeleted(_selectedPath!)) {
      _selectedPath = _multiSelection.isEmpty ? null : _multiSelection.last;
    }
  }

  FileTreeItem? get root => _root;
  String? get workspacePath => _workspacePath;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedPath => _selectedPath;
  SortConfig get sortConfig => _sortConfig;
  String? get creatingInPath => _creatingInPath;
  bool get creatingIsDirectory => _creatingIsDirectory;
  String get searchQuery => _searchQuery;
  ExplorerSearchMode get searchMode => _searchMode;
  bool get isSearching => _isSearching;
  Map<String, String> get gitStatuses => Map.unmodifiable(_gitStatuses);
  bool get hasClipboardItems => _clipboardPaths?.isNotEmpty ?? false;
  bool get clipboardIsCut => _clipboardIsCut;
  List<String> get clipboardPaths =>
      List.unmodifiable(_clipboardPaths ?? const <String>[]);
  bool get showHiddenFiles => _showHiddenFiles;
  List<String> get selectedPaths => List.unmodifiable(_multiSelection);
  Future<bool> exists(String path) => _fileService.exists(path);

  Future<List<FileTreeItem>> listDirectoryForNavigation(String path) async {
    final children = await _fileService.listDirectory(path);
    return List.unmodifiable(_sortChildren(children).where(_shouldShow));
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> openWorkspace(String path) async {
    final directory = Directory(path).absolute;
    if (!await directory.exists()) {
      throw FileSystemException('Workspace directory does not exist', path);
    }

    _isLoading = true;
    _searchGeneration++;
    _gitStatusGeneration++;
    _gitStatuses = {};
    _searchDebouncer?.cancel();
    _searchQuery = '';
    _searchResultPaths.clear();
    _searchAncestorPaths.clear();
    _isSearching = false;
    _error = null;
    notifyListeners();
    try {
      final normalizedPath = directory.path;
      final root = FileTreeItem(
        name: _basename(normalizedPath),
        path: normalizedPath,
        isDirectory: true,
      );
      root.children = await _fileService.listDirectory(normalizedPath);
      _root = root;
      _workspacePath = normalizedPath;
      _expandedPaths
        ..clear()
        ..add(normalizedPath);
      _selectedPath = null;
      _multiSelection.clear();
      _invalidateItems();
      await _watcherService.watch(normalizedPath);
      await restoreState();
      _scheduleGitStatusRefresh();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleExpand(FileTreeItem item) async {
    if (!item.isDirectory) return;
    if (_expandedPaths.remove(item.path)) {
      _invalidateItems();
      _saveState();
      notifyListeners();
      return;
    }
    if (!item.isResolved) {
      _isLoading = true;
      notifyListeners();
      try {
        item.children = await _fileService.listDirectory(item.path);
      } catch (error) {
        _error = error.toString();
        rethrow;
      } finally {
        _isLoading = false;
      }
    }
    _expandedPaths.add(item.path);
    _invalidateItems();
    _saveState();
    notifyListeners();
  }

  Future<void> expandTo(String path) async {
    final root = _root;
    if (root == null || !_isWithinWorkspace(path)) return;
    final absolutePath = File(path).absolute.path;
    final relative = absolutePath.substring(root.path.length);
    final segments = relative
        .split(Platform.pathSeparator)
        .where((segment) => segment.isNotEmpty)
        .toList();
    var current = root;
    for (final segment in segments) {
      if (!current.isResolved) {
        current.children = await _fileService.listDirectory(current.path);
      }
      _expandedPaths.add(current.path);
      final nextPath = _join(current.path, segment);
      final match = current.children.where((child) => child.path == nextPath);
      if (match.isEmpty) return;
      current = match.first;
    }
    _invalidateItems();
    _saveState();
    notifyListeners();
  }

  Future<void> revealAndSelect(String path) async {
    await expandTo(path);
    final item = findItem(File(path).absolute.path);
    if (item != null) select(item);
  }

  void collapseAll() {
    _expandedPaths
      ..clear()
      ..addAll(_root == null ? const <String>[] : [_root!.path]);
    _invalidateItems();
    _saveState();
    notifyListeners();
  }

  void collapse(FileTreeItem item) {
    _expandedPaths.remove(item.path);
    _invalidateItems();
    _saveState();
    notifyListeners();
  }

  void select(FileTreeItem item) {
    _selectedPath = item.path;
    _multiSelection
      ..clear()
      ..add(item.path);
    notifyListeners();
  }

  void multiSelect(FileTreeItem item) {
    if (_multiSelection.add(item.path)) {
      _selectedPath = item.path;
    } else {
      _multiSelection.remove(item.path);
      if (_multiSelection.isEmpty) {
        _selectedPath = null;
      } else if (_selectedPath == item.path) {
        _selectedPath = _multiSelection.last;
      }
    }
    notifyListeners();
  }

  bool isExpanded(FileTreeItem item) => _expandedPaths.contains(item.path);
  bool isSelected(FileTreeItem item) => _selectedPath == item.path;
  bool isEditing(String path) => _editingPath == path;
  bool isCut(String path) =>
      _clipboardIsCut && (_clipboardPaths?.contains(path) ?? false);

  Future<FileTreeItem> createFile(String parentPath, String name) async {
    final result = await _fileService.createFile(_join(parentPath, name));
    await refresh(path: parentPath);
    _scheduleGitStatusRefresh();
    cancelEdit();
    select(findItem(result.path) ?? result);
    return result;
  }

  Future<FileTreeItem> createDirectory(String parentPath, String name) async {
    final result = await _fileService.createDirectory(_join(parentPath, name));
    await refresh(path: parentPath);
    _scheduleGitStatusRefresh();
    cancelEdit();
    select(findItem(result.path) ?? result);
    return result;
  }

  Future<void> delete(List<String> paths) async {
    final normalized = _normalizeSelection(paths);
    try {
      for (final path in normalized) {
        await _fileService.delete(path, recursive: true);
        _removeSelectionForPath(path);
      }
    } catch (_) {
      try {
        await _refreshParents(normalized);
      } catch (refreshError) {
        _error = 'Unable to refresh after a partial delete: $refreshError';
        notifyListeners();
      }
      _scheduleGitStatusRefresh();
      rethrow;
    }
    await _refreshParents(normalized);
    _scheduleGitStatusRefresh();
  }

  Future<void> rename(String path, String newName) async {
    final result = await _fileService.rename(path, newName);
    final parentPath = _dirname(path);
    _remapPaths(path, result.path);
    cancelEdit();
    await refresh(path: parentPath);
    _scheduleGitStatusRefresh();
  }

  Future<void> move(List<String> sourcePaths, String targetDir) async {
    final paths = _normalizeSelection(sourcePaths);
    try {
      for (final path in paths) {
        final result = await _fileService.move(path, targetDir);
        _remapPaths(path, result.path);
      }
    } catch (_) {
      try {
        await _refreshParents(paths);
        await refresh(path: targetDir);
      } catch (refreshError) {
        _error = 'Unable to refresh after a partial move: $refreshError';
        notifyListeners();
      }
      _scheduleGitStatusRefresh();
      rethrow;
    }
    _clipboardPaths = null;
    await _refreshParents(paths);
    await refresh(path: targetDir);
    _scheduleGitStatusRefresh();
  }

  Future<void> copy(List<String> sourcePaths, String targetDir) async {
    final paths = _normalizeSelection(sourcePaths);
    try {
      for (final path in paths) {
        await _fileService.copy(path, targetDir);
      }
    } catch (_) {
      try {
        await refresh(path: targetDir);
      } catch (refreshError) {
        _error = 'Unable to refresh after a partial copy: $refreshError';
        notifyListeners();
      }
      _scheduleGitStatusRefresh();
      rethrow;
    }
    await refresh(path: targetDir);
    _scheduleGitStatusRefresh();
  }

  void cut(List<String> paths) {
    _clipboardPaths = _normalizeSelection(paths);
    _clipboardIsCut = true;
    notifyListeners();
  }

  void copyToClipboard(List<String> paths) {
    _clipboardPaths = _normalizeSelection(paths);
    _clipboardIsCut = false;
    notifyListeners();
  }

  Future<void> paste(String targetDir) async {
    final paths = _clipboardPaths;
    if (paths == null || paths.isEmpty) return;
    if (_clipboardIsCut) {
      await move(paths, targetDir);
    } else {
      await copy(paths, targetDir);
    }
  }

  void startRename(String path) {
    _editingPath = path;
    _creatingInPath = null;
    notifyListeners();
  }

  void startCreate(String parentPath, {bool isDirectory = false}) {
    _editingPath = null;
    _creatingInPath = parentPath;
    _creatingIsDirectory = isDirectory;
    _expandedPaths.add(parentPath);
    final parent = findItem(parentPath);
    if (parent != null && !parent.isResolved) {
      _isLoading = true;
      unawaited(
        _fileService
            .listDirectory(parent.path)
            .then((children) {
              parent.children = children;
              _isLoading = false;
              _invalidateItems();
              notifyListeners();
            })
            .catchError((Object error) {
              _isLoading = false;
              _error = error.toString();
              notifyListeners();
            }),
      );
    } else {
      _invalidateItems();
      notifyListeners();
    }
  }

  void cancelEdit() {
    _editingPath = null;
    _creatingInPath = null;
    _invalidateItems();
    notifyListeners();
  }

  void updateSortConfig(SortConfig config) {
    _sortConfig = config;
    _invalidateItems();
    notifyListeners();
  }

  void setShowHiddenFiles(bool value) {
    if (_showHiddenFiles == value) return;
    _showHiddenFiles = value;
    setSearchQuery(_searchQuery);
  }

  void setSearchQuery(String query) {
    final normalizedQuery = query.trim();
    _searchQuery = normalizedQuery;
    _searchGeneration++;
    final generation = _searchGeneration;
    _searchDebouncer?.cancel();
    _searchResultPaths = {};
    _searchAncestorPaths = {};
    _isSearching = normalizedQuery.isNotEmpty;
    _invalidateItems();
    notifyListeners();
    if (normalizedQuery.isEmpty) return;
    _searchDebouncer = Timer(const Duration(milliseconds: 200), () {
      unawaited(_searchWorkspace(normalizedQuery, generation));
    });
  }

  void setSearchMode(ExplorerSearchMode mode) {
    if (_searchMode == mode) return;
    _searchMode = mode;
    _invalidateItems();
    notifyListeners();
  }

  bool isSearchMatch(String path) =>
      _searchQuery.isNotEmpty && _searchResultPaths.contains(path);

  String? gitStatusFor(String path, {bool isDirectory = false}) {
    final exact = _gitStatuses[path];
    if (exact != null || !isDirectory) return exact;
    final prefix = '$path${Platform.pathSeparator}';
    final descendants = _gitStatuses.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value);
    final statuses = descendants.toSet();
    if (statuses.isEmpty) return null;
    if (statuses.contains('M') || statuses.contains('D')) return 'M';
    if (statuses.contains('A')) return 'A';
    if (statuses.contains('R')) return 'R';
    return 'U';
  }

  Future<void> refreshGitStatus() async {
    final workspace = _workspacePath;
    if (workspace == null) return;
    final generation = ++_gitStatusGeneration;
    try {
      final result = await Process.run('git', [
        '-C',
        workspace,
        '-c',
        'core.quotepath=false',
        'status',
        '--porcelain=v1',
        '-z',
        '--untracked-files=all',
      ]);
      if (_disposed || generation != _gitStatusGeneration) return;
      if (result.exitCode != 0) {
        final message = '${result.stderr}'.trim();
        if (message.toLowerCase().contains('not a git repository')) {
          _gitStatuses = {};
          notifyListeners();
          return;
        }
        throw ProcessException(
          'git',
          ['status', '--porcelain=v1'],
          message,
          result.exitCode,
        );
      }

      final statuses = <String, String>{};
      final entries = '${result.stdout}'.split('\u0000');
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (entry.length < 4) continue;
        final state = entry.substring(0, 2);
        final path = entry.substring(3);
        final status = state.contains('D')
            ? 'D'
            : state.contains('A')
            ? 'A'
            : state.contains('R')
            ? 'R'
            : state.contains('M')
            ? 'M'
            : state.contains('?')
            ? 'U'
            : '';
        if (status.isNotEmpty) {
          statuses[_join(
                workspace,
                path.replaceAll('/', Platform.pathSeparator),
              )] =
              status;
        }
        if (state.contains('R') || state.contains('C')) {
          index++;
        }
      }
      _gitStatuses = statuses;
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _gitStatusGeneration) return;
      _error = 'Unable to read Git status: $error';
      notifyListeners();
    }
  }

  void _scheduleGitStatusRefresh() {
    _gitStatusDebouncer?.cancel();
    _gitStatusDebouncer = Timer(const Duration(milliseconds: 350), () {
      unawaited(refreshGitStatus());
    });
  }

  Future<void> _searchWorkspace(String query, int generation) async {
    final workspace = _workspacePath;
    if (workspace == null) {
      _isSearching = false;
      notifyListeners();
      return;
    }
    try {
      final matches = await _fileService.searchPaths(
        workspace,
        query,
        showHiddenFiles: _showHiddenFiles,
      );
      if (_disposed || generation != _searchGeneration) return;

      final results = <String>{};
      final ancestors = <String>{};
      for (final match in matches) {
        results.add(match);
        var parent = _dirname(match);
        while (parent != workspace &&
            parent.startsWith('$workspace${Platform.pathSeparator}')) {
          ancestors.add(parent);
          parent = _dirname(parent);
        }
      }
      _searchResultPaths = results;
      _searchAncestorPaths = ancestors;
      await _resolveSearchAncestors(workspace, ancestors, generation);
      if (_disposed || generation != _searchGeneration) return;
      _isSearching = false;
      _invalidateItems();
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _searchGeneration) return;
      _isSearching = false;
      _error = 'Unable to search workspace: $error';
      notifyListeners();
    }
  }

  Future<void> _resolveSearchAncestors(
    String path,
    Set<String> ancestors,
    int generation,
  ) async {
    if (generation != _searchGeneration || _disposed) return;
    final directory = findItem(path);
    if (directory == null || !directory.isDirectory) return;
    if (!directory.isResolved) {
      directory.children = await _fileService.listDirectory(directory.path);
    }
    for (final child in directory.children) {
      if (ancestors.contains(child.path)) {
        _expandedPaths.add(child.path);
        await _resolveSearchAncestors(child.path, ancestors, generation);
      }
    }
  }

  Future<void> refresh({String? path}) async {
    final root = _root;
    if (root == null) return;
    final requestedPath = path ?? root.path;
    final item = findItem(requestedPath);
    final directoryPath = item?.isDirectory == true
        ? item!.path
        : _dirname(requestedPath);
    final directoryItem = findItem(directoryPath);
    if (directoryItem == null && directoryPath != root.path) return;
    try {
      final refreshed = await _fileService.listDirectory(directoryPath);
      final target = directoryItem ?? root;
      target.children = refreshed;
      _invalidateItems();
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  FileTreeItem? findItem(String path) => _root?.find(path);

  List<FileTreeItem> getVisibleItems() {
    if (!_isDirty && _cachedVisibleItems != null) return _cachedVisibleItems!;
    final result = <FileTreeItem>[];
    final root = _root;
    if (root != null) {
      void walk(FileTreeItem item) {
        if (!_shouldShow(item) || !_matchesSearch(item)) return;
        result.add(item);
        if (item.isDirectory &&
            (isExpanded(item) || _searchAncestorPaths.contains(item.path)) &&
            item.isResolved) {
          for (final child in _sortChildren(item.children)) {
            walk(child);
          }
        }
      }

      for (final child in _sortChildren(root.children)) {
        walk(child);
      }
    }
    _cachedVisibleItems = List.unmodifiable(result);
    _isDirty = false;
    return _cachedVisibleItems!;
  }

  Future<void> saveState() async {
    final stateFile = _stateFile();
    if (stateFile == null || _workspacePath == null) return;
    await stateFile.parent.create(recursive: true);
    await stateFile.writeAsString(
      jsonEncode({
        'workspace': _workspacePath,
        'expanded': _expandedPaths.toList(),
      }),
    );
  }

  Future<void> restoreState() async {
    final stateFile = _stateFile();
    if (stateFile == null ||
        !await stateFile.exists() ||
        _workspacePath == null) {
      return;
    }
    final decoded = jsonDecode(await stateFile.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['workspace'] != _workspacePath ||
        decoded['expanded'] is! List) {
      return;
    }
    final paths = (decoded['expanded'] as List).whereType<String>();
    for (final path in paths) {
      if (_isWithinWorkspace(path)) await expandTo(path);
    }
  }

  void _onFileChanged(List<FileChangeEvent> events) {
    if (_disposed) return;
    final rootPath = _workspacePath;
    if (rootPath == null) return;
    final affected = <String>{};
    for (final event in events) {
      if (!_isWithinWorkspace(event.path)) continue;
      final path = event.type == FileChangeType.deleted
          ? _dirname(event.path)
          : event.path;
      final item = findItem(path);
      final directory = item?.isDirectory == true ? path : _dirname(path);
      if (_expandedPaths.contains(directory) || directory == rootPath) {
        affected.add(directory);
      }
    }
    if (affected.isEmpty) {
      _scheduleGitStatusRefresh();
      return;
    }
    _refreshDebouncer?.cancel();
    _refreshDebouncer = Timer(const Duration(milliseconds: 150), () async {
      if (_disposed) return;
      for (final path in affected) {
        try {
          await refresh(path: path);
        } catch (error) {
          _error =
              'Unable to refresh "$path" after a filesystem change: $error';
          notifyListeners();
        }
      }
      _scheduleGitStatusRefresh();
    });
  }

  Future<void> _refreshParents(List<String> paths) async {
    final parents = paths.map(_dirname).toSet();
    for (final parent in parents) {
      await refresh(path: parent);
    }
  }

  List<String> _normalizeSelection(List<String> paths) {
    final unique = paths.toSet().toList();
    return unique
        .where(
          (path) => !unique.any(
            (other) =>
                other != path &&
                path.startsWith('$other${Platform.pathSeparator}'),
          ),
        )
        .toList();
  }

  List<FileTreeItem> _sortChildren(List<FileTreeItem> children) {
    final result = children.where(_shouldShow).toList();
    int compare(FileTreeItem a, FileTreeItem b) {
      if (_sortConfig.folderPosition != FolderPosition.mixed &&
          a.isDirectory != b.isDirectory) {
        final foldersFirst = _sortConfig.folderPosition == FolderPosition.first;
        return a.isDirectory == foldersFirst ? -1 : 1;
      }
      int comparison;
      switch (_sortConfig.order) {
        case SortOrder.name:
          final left = _sortConfig.caseSensitive
              ? a.name
              : a.name.toLowerCase();
          final right = _sortConfig.caseSensitive
              ? b.name
              : b.name.toLowerCase();
          comparison = left.compareTo(right);
        case SortOrder.type:
          comparison = a.extension.compareTo(b.extension);
          if (comparison == 0) {
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
        case SortOrder.modified:
          comparison = (a.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                b.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              );
        case SortOrder.size:
          comparison = (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);
      }
      return _sortConfig.direction == SortDirection.ascending
          ? comparison
          : -comparison;
    }

    result.sort(compare);
    return result;
  }

  bool _shouldShow(FileTreeItem item) {
    const excluded = {
      '.git',
      '.dart_tool',
      'build',
      '.idea',
      '.vscode',
      'node_modules',
      '.DS_Store',
    };
    if (excluded.contains(item.name)) return false;
    return _showHiddenFiles || !item.isHidden;
  }

  bool _matchesSearch(FileTreeItem item) {
    if (_searchQuery.isEmpty) return true;
    if (_searchMode == ExplorerSearchMode.highlight) return true;
    return _searchResultPaths.contains(item.path) ||
        _searchAncestorPaths.contains(item.path);
  }

  bool _isWithinWorkspace(String path) {
    final root = _workspacePath;
    if (root == null) return false;
    final absolute = File(path).absolute.path;
    return absolute == root ||
        absolute.startsWith('$root${Platform.pathSeparator}');
  }

  File? _stateFile() {
    if (!persistState) return null;
    final home = Platform.isWindows
        ? Platform.environment['APPDATA']
        : Platform.environment['HOME'];
    if (home == null) return null;
    final path = Platform.isWindows
        ? _join(home, 'code_editor_explorer_state.json')
        : _join(_join(home, '.config'), 'code_editor_explorer_state.json');
    return File(path);
  }

  void _invalidateItems() {
    _cachedVisibleItems = null;
    _isDirty = true;
  }

  void _saveState() {
    unawaited(
      saveState().catchError((Object error) {
        _error = 'Unable to save explorer state: $error';
        if (!_disposed) notifyListeners();
      }),
    );
  }

  bool canMoveTo(FileTreeItem source, FileTreeItem target) {
    if (!target.isDirectory ||
        source.path == target.path ||
        source.parent?.path == target.path) {
      return false;
    }
    return !target.path.startsWith('${source.path}${Platform.pathSeparator}');
  }

  void _remapPaths(String oldPath, String newPath) {
    String remap(String path) => path == oldPath
        ? newPath
        : path.startsWith('$oldPath${Platform.pathSeparator}')
        ? '$newPath${path.substring(oldPath.length)}'
        : path;

    final expanded = _expandedPaths.map(remap).toList();
    _expandedPaths
      ..clear()
      ..addAll(expanded);
    _selectedPath = _selectedPath == null ? null : remap(_selectedPath!);
    final selected = _multiSelection.map(remap).toList();
    _multiSelection
      ..clear()
      ..addAll(selected);
    if (_clipboardPaths != null) {
      _clipboardPaths = _clipboardPaths!.map(remap).toList();
    }
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final end = normalized.endsWith('/')
        ? normalized.length - 1
        : normalized.length;
    return normalized.substring(normalized.lastIndexOf('/', end - 1) + 1, end);
  }

  String _dirname(String path) {
    final index = path.lastIndexOf(Platform.pathSeparator);
    return index <= 0 ? Platform.pathSeparator : path.substring(0, index);
  }

  String _join(String directory, String name) =>
      directory.endsWith(Platform.pathSeparator)
      ? '$directory$name'
      : '$directory${Platform.pathSeparator}$name';

  @override
  void dispose() {
    _disposed = true;
    _refreshDebouncer?.cancel();
    _searchDebouncer?.cancel();
    _gitStatusDebouncer?.cancel();
    unawaited(_watcherSubscription.cancel());
    unawaited(_watcherService.dispose());
    super.dispose();
  }
}

class FileExplorerScope extends InheritedNotifier<FileExplorerController> {
  const FileExplorerScope({
    super.key,
    required FileExplorerController super.notifier,
    required super.child,
  });

  static FileExplorerController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FileExplorerScope>();
    assert(scope != null, 'FileExplorerScope not found in context');
    return scope!.notifier!;
  }
}
