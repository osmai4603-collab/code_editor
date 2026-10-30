import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/file_tree_item.dart';
import '../models/file_explorer_state.dart';
import '../models/explorer_selection_state.dart';
import '../models/sort_config.dart';
import '../services/explorer_persistence_store.dart';
import '../services/explorer_search_service.dart';
import '../services/explorer_file_operations.dart';
import '../services/file_system_service.dart';
import '../services/file_watcher_service.dart';
import '../services/git_status_service.dart';
import '../utils/file_tree_sorter.dart';

enum ExplorerSearchMode { filter, highlight }

class FileExplorerCoordinator extends ChangeNotifier {
  final FileSystemService _fileService;
  final FileWatcherService _watcherService;
  final IGitStatusService _gitStatusService;
  final ExplorerSearchService _searchService;
  final IExplorerPersistenceStore? _persistenceStore;
  late final ExplorerFileOperations _fileOperations = ExplorerFileOperations(
    fileSystemService: _fileService,
    refreshDirectory: (path) => refresh(path: path),
    refreshParents: _refreshParents,
    removeSelection: _selection.removePath,
    remapPaths: _remapPaths,
    reportPartialFailure: (message) {
      _error = message;
      notifyListeners();
    },
    scheduleGitStatusRefresh: _scheduleGitStatusRefresh,
  );
  final FileTreeSorter fileTreeSorter;
  final bool persistState;
  late final StreamSubscription<List<FileChangeEvent>> _watcherSubscription;

  FileTreeItem? _root;
  String? _workspacePath;
  final Set<String> _expandedPaths = {};
  final ExplorerSelectionState _selection = ExplorerSelectionState();
  SortConfig _sortConfig = const SortConfig.defaultConfig();
  bool _isLoading = false;
  String? _error;
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

  FileExplorerCoordinator({
    required FileSystemService fileService,
    required this._watcherService,
    this.persistState = true,
    IGitStatusService? gitStatusService,
    ExplorerSearchService? searchService,
    IExplorerPersistenceStore? persistenceStore,
    this.fileTreeSorter = const FileTreeSorter(),
  }) : _gitStatusService = gitStatusService ?? ProcessGitStatusService(),
       _fileService = fileService,
       _searchService = searchService ?? ExplorerSearchService(fileService),
       _persistenceStore = persistenceStore ?? JsonExplorerPersistenceStore() {
    _watcherSubscription = _watcherService.changes.listen(
      _onFileChanged,
      onError: (Object error, StackTrace stackTrace) {
        _error = 'File watcher failed: $error';
        notifyListeners();
      },
    );
  }

  FileTreeItem? get root => _root;
  FileExplorerState get state => FileExplorerState(
    rootPath: _workspacePath,
    expandedPaths: _expandedPaths,
    selectedPath: _selection.selectedPath,
    searchQuery: _searchQuery,
    gitStatuses: _gitStatuses,
    isLoading: _isLoading,
    error: _error,
  );
  String? get workspacePath => _workspacePath;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedPath => _selection.selectedPath;
  SortConfig get sortConfig => _sortConfig;
  String? get creatingInPath => _selection.creatingInPath;
  bool get creatingIsDirectory => _selection.creatingIsDirectory;
  String get searchQuery => _searchQuery;
  ExplorerSearchMode get searchMode => _searchMode;
  bool get isSearching => _isSearching;
  Map<String, String> get gitStatuses => Map.unmodifiable(_gitStatuses);
  bool get hasClipboardItems => _selection.hasClipboardItems;
  bool get clipboardIsCut => _selection.clipboardIsCut;
  List<String> get clipboardPaths => _selection.clipboardItems;
  bool get showHiddenFiles => _showHiddenFiles;
  List<String> get selectedPaths => _selection.selectedItems;
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
      _selection
        ..selectedPath = null
        ..selectedPaths.clear();
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
    _selection.select(item);
    notifyListeners();
  }

  void multiSelect(FileTreeItem item) {
    _selection.toggleSelection(item);
    notifyListeners();
  }

  bool isExpanded(FileTreeItem item) => _expandedPaths.contains(item.path);
  bool isSelected(FileTreeItem item) => _selection.selectedPath == item.path;
  bool isEditing(String path) => _selection.editingPath == path;
  bool isCut(String path) =>
      _selection.clipboardIsCut &&
      (_selection.clipboardPaths?.contains(path) ?? false);

  Future<FileTreeItem> createFile(String parentPath, String name) async {
    final result = await _fileOperations.createFile(parentPath, name);
    cancelEdit();
    select(findItem(result.path) ?? result);
    return result;
  }

  Future<FileTreeItem> createDirectory(String parentPath, String name) async {
    final result = await _fileOperations.createDirectory(parentPath, name);
    cancelEdit();
    select(findItem(result.path) ?? result);
    return result;
  }

  Future<void> delete(List<String> paths) async {
    final normalized = _selection.normalizePaths(paths);
    await _fileOperations.delete(normalized);
  }

  Future<void> rename(String path, String newName) async {
    await _fileOperations.rename(path, newName);
    cancelEdit();
  }

  Future<void> move(List<String> sourcePaths, String targetDir) async {
    final paths = _selection.normalizePaths(sourcePaths);
    await _fileOperations.move(paths, targetDir);
    _selection.clipboardPaths = null;
  }

  Future<void> copy(List<String> sourcePaths, String targetDir) async {
    final paths = _selection.normalizePaths(sourcePaths);
    await _fileOperations.copy(paths, targetDir);
  }

  void cut(List<String> paths) {
    _selection.clipboardPaths = _selection.normalizePaths(paths);
    _selection.clipboardIsCut = true;
    notifyListeners();
  }

  void copyToClipboard(List<String> paths) {
    _selection.clipboardPaths = _selection.normalizePaths(paths);
    _selection.clipboardIsCut = false;
    notifyListeners();
  }

  Future<void> paste(String targetDir) async {
    final paths = _selection.clipboardPaths;
    if (paths == null || paths.isEmpty) return;
    if (_selection.clipboardIsCut) {
      await move(paths, targetDir);
    } else {
      await copy(paths, targetDir);
    }
  }

  void startRename(String path) {
    _selection.editingPath = path;
    _selection.creatingInPath = null;
    notifyListeners();
  }

  void startCreate(String parentPath, {bool isDirectory = false}) {
    _selection.editingPath = null;
    _selection.creatingInPath = parentPath;
    _selection.creatingIsDirectory = isDirectory;
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
    _selection.editingPath = null;
    _selection.creatingInPath = null;
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
      final statuses = await _gitStatusService.refreshStatus(workspace);
      if (_disposed || generation != _gitStatusGeneration) return;
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
      final result = await _searchService.search(
        workspace,
        query,
        showHiddenFiles: _showHiddenFiles,
      );
      if (_disposed || generation != _searchGeneration) return;

      _searchResultPaths = result.matches;
      _searchAncestorPaths = result.ancestors;
      await _resolveSearchAncestors(workspace, result.ancestors, generation);
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
    if (!persistState || _workspacePath == null) return;
    await _persistenceStore?.save(
      ExplorerPersistedState(
        workspacePath: _workspacePath!,
        expandedPaths: _expandedPaths,
        selectedPath: _selection.selectedPath,
      ),
    );
  }

  Future<void> restoreState() async {
    final workspace = _workspacePath;
    if (!persistState || workspace == null || _persistenceStore == null) {
      return;
    }
    final state = await _persistenceStore.load(workspace);
    if (state == null || state.workspacePath != workspace) return;
    for (final path in state.expandedPaths) {
      if (_isWithinWorkspace(path)) await expandTo(path);
    }
    if (state.selectedPath != null && _isWithinWorkspace(state.selectedPath!)) {
      await revealAndSelect(state.selectedPath!);
      await saveState();
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

  List<FileTreeItem> _sortChildren(List<FileTreeItem> children) {
    return fileTreeSorter.sort(children.where(_shouldShow), _sortConfig);
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
    _selection.remapPaths(oldPath, newPath);
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
