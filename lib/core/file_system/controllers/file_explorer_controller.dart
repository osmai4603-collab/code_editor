import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/file_tree_item.dart';
import '../models/sort_config.dart';
import '../services/file_system_service.dart';
import '../services/file_watcher_service.dart';

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

  FileTreeItem? get root => _root;
  String? get workspacePath => _workspacePath;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedPath => _selectedPath;
  SortConfig get sortConfig => _sortConfig;
  String? get creatingInPath => _creatingInPath;
  bool get creatingIsDirectory => _creatingIsDirectory;
  String get searchQuery => _searchQuery;
  bool get hasClipboardItems => _clipboardPaths?.isNotEmpty ?? false;
  bool get clipboardIsCut => _clipboardIsCut;
  List<String> get clipboardPaths =>
      List.unmodifiable(_clipboardPaths ?? const <String>[]);
  bool get showHiddenFiles => _showHiddenFiles;
  List<String> get selectedPaths => List.unmodifiable(_multiSelection);
  Future<bool> exists(String path) => _fileService.exists(path);

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
    if (!_multiSelection.add(item.path)) _multiSelection.remove(item.path);
    _selectedPath = item.path;
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
    cancelEdit();
    select(findItem(result.path) ?? result);
    return result;
  }

  Future<FileTreeItem> createDirectory(String parentPath, String name) async {
    final result = await _fileService.createDirectory(_join(parentPath, name));
    await refresh(path: parentPath);
    cancelEdit();
    select(findItem(result.path) ?? result);
    return result;
  }

  Future<void> delete(List<String> paths) async {
    final normalized = _normalizeSelection(paths);
    for (final path in normalized) {
      await _fileService.delete(path, recursive: true);
    }
    bool isDeleted(String candidate) => normalized.any(
      (path) =>
          candidate == path ||
          candidate.startsWith('$path${Platform.pathSeparator}'),
    );
    _multiSelection.removeWhere(isDeleted);
    if (_selectedPath != null && isDeleted(_selectedPath!)) {
      _selectedPath = null;
    }
    await _refreshParents(normalized);
  }

  Future<void> rename(String path, String newName) async {
    final result = await _fileService.rename(path, newName);
    final parentPath = _dirname(path);
    _remapPaths(path, result.path);
    cancelEdit();
    await refresh(path: parentPath);
  }

  Future<void> move(List<String> sourcePaths, String targetDir) async {
    final paths = _normalizeSelection(sourcePaths);
    for (final path in paths) {
      final result = await _fileService.move(path, targetDir);
      _remapPaths(path, result.path);
    }
    _clipboardPaths = null;
    await _refreshParents(paths);
    await refresh(path: targetDir);
  }

  Future<void> copy(List<String> sourcePaths, String targetDir) async {
    final paths = _normalizeSelection(sourcePaths);
    for (final path in paths) {
      await _fileService.copy(path, targetDir);
    }
    await refresh(path: targetDir);
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
    _showHiddenFiles = value;
    _invalidateItems();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _invalidateItems();
    notifyListeners();
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
            (isExpanded(item) || _searchQuery.isNotEmpty) &&
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
    if (affected.isEmpty) return;
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
    final query = _searchQuery.toLowerCase();
    if (item.name.toLowerCase().contains(query)) return true;
    return item.isDirectory &&
        item.children.any((child) => _matchesSearch(child));
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
