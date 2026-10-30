import 'package:flutter/widgets.dart';

import '../models/file_explorer_state.dart';
import '../models/file_tree_item.dart';
import '../models/sort_config.dart';
import '../services/explorer_persistence_store.dart';
import '../services/explorer_search_service.dart';
import '../services/file_system_service.dart';
import '../services/file_watcher_service.dart';
import '../services/git_status_service.dart';
import '../utils/file_tree_sorter.dart';
import 'file_explorer_coordinator.dart';

export 'file_explorer_coordinator.dart' show ExplorerSearchMode;

/// Public facade for the file explorer's workspace and tree operations.
class FileExplorerController extends ChangeNotifier {
  late final FileExplorerCoordinator _coordinator;

  FileExplorerController({
    required FileSystemService fileService,
    required FileWatcherService watcherService,
    bool persistState = true,
    IGitStatusService? gitStatusService,
    ExplorerSearchService? searchService,
    IExplorerPersistenceStore? persistenceStore,
    FileTreeSorter fileTreeSorter = const FileTreeSorter(),
  }) {
    _coordinator = FileExplorerCoordinator(
      fileService: fileService,
      watcherService: watcherService,
      persistState: persistState,
      gitStatusService: gitStatusService,
      searchService: searchService,
      persistenceStore: persistenceStore,
      fileTreeSorter: fileTreeSorter,
    )..addListener(_notifyChanged);
  }

  void _notifyChanged() {
    if (hasListeners) notifyListeners();
  }

  FileTreeItem? get root => _coordinator.root;
  FileExplorerState get state => _coordinator.state;
  String? get workspacePath => _coordinator.workspacePath;
  bool get isLoading => _coordinator.isLoading;
  String? get error => _coordinator.error;
  bool get persistState => _coordinator.persistState;
  FileTreeSorter get fileTreeSorter => _coordinator.fileTreeSorter;
  String? get selectedPath => _coordinator.selectedPath;
  SortConfig get sortConfig => _coordinator.sortConfig;
  String? get creatingInPath => _coordinator.creatingInPath;
  bool get creatingIsDirectory => _coordinator.creatingIsDirectory;
  String get searchQuery => _coordinator.searchQuery;
  ExplorerSearchMode get searchMode => _coordinator.searchMode;
  bool get isSearching => _coordinator.isSearching;
  Map<String, String> get gitStatuses => _coordinator.gitStatuses;
  bool get hasClipboardItems => _coordinator.hasClipboardItems;
  bool get clipboardIsCut => _coordinator.clipboardIsCut;
  List<String> get clipboardPaths => _coordinator.clipboardPaths;
  bool get showHiddenFiles => _coordinator.showHiddenFiles;
  List<String> get selectedPaths => _coordinator.selectedPaths;

  Future<bool> exists(String path) => _coordinator.exists(path);

  Future<List<FileTreeItem>> listDirectoryForNavigation(String path) =>
      _coordinator.listDirectoryForNavigation(path);

  void clearError() => _coordinator.clearError();
  Future<void> openWorkspace(String path) => _coordinator.openWorkspace(path);
  Future<void> toggleExpand(FileTreeItem item) =>
      _coordinator.toggleExpand(item);
  Future<void> expandTo(String path) => _coordinator.expandTo(path);
  Future<void> revealAndSelect(String path) =>
      _coordinator.revealAndSelect(path);
  void collapseAll() => _coordinator.collapseAll();
  void collapse(FileTreeItem item) => _coordinator.collapse(item);
  void select(FileTreeItem item) => _coordinator.select(item);
  void multiSelect(FileTreeItem item) => _coordinator.multiSelect(item);
  bool isExpanded(FileTreeItem item) => _coordinator.isExpanded(item);
  bool isSelected(FileTreeItem item) => _coordinator.isSelected(item);
  bool isEditing(String path) => _coordinator.isEditing(path);
  bool isCut(String path) => _coordinator.isCut(path);

  Future<FileTreeItem> createFile(String parentPath, String name) =>
      _coordinator.createFile(parentPath, name);

  Future<FileTreeItem> createDirectory(String parentPath, String name) =>
      _coordinator.createDirectory(parentPath, name);

  Future<void> delete(List<String> paths) => _coordinator.delete(paths);
  Future<void> rename(String path, String newName) =>
      _coordinator.rename(path, newName);
  Future<void> move(List<String> sourcePaths, String targetDir) =>
      _coordinator.move(sourcePaths, targetDir);
  Future<void> copy(List<String> sourcePaths, String targetDir) =>
      _coordinator.copy(sourcePaths, targetDir);
  void cut(List<String> paths) => _coordinator.cut(paths);
  void copyToClipboard(List<String> paths) =>
      _coordinator.copyToClipboard(paths);
  Future<void> paste(String targetDir) => _coordinator.paste(targetDir);
  void startRename(String path) => _coordinator.startRename(path);
  void startCreate(String parentPath, {bool isDirectory = false}) =>
      _coordinator.startCreate(parentPath, isDirectory: isDirectory);
  void cancelEdit() => _coordinator.cancelEdit();
  void updateSortConfig(SortConfig config) =>
      _coordinator.updateSortConfig(config);
  void setShowHiddenFiles(bool value) => _coordinator.setShowHiddenFiles(value);
  void setSearchQuery(String query) => _coordinator.setSearchQuery(query);
  void setSearchMode(ExplorerSearchMode mode) =>
      _coordinator.setSearchMode(mode);
  bool isSearchMatch(String path) => _coordinator.isSearchMatch(path);

  String? gitStatusFor(String path, {bool isDirectory = false}) =>
      _coordinator.gitStatusFor(path, isDirectory: isDirectory);

  Future<void> refreshGitStatus() => _coordinator.refreshGitStatus();
  Future<void> refresh({String? path}) => _coordinator.refresh(path: path);
  FileTreeItem? findItem(String path) => _coordinator.findItem(path);
  List<FileTreeItem> getVisibleItems() => _coordinator.getVisibleItems();
  Future<void> saveState() => _coordinator.saveState();
  Future<void> restoreState() => _coordinator.restoreState();
  bool canMoveTo(FileTreeItem source, FileTreeItem target) =>
      _coordinator.canMoveTo(source, target);

  @override
  void dispose() {
    _coordinator
      ..removeListener(_notifyChanged)
      ..dispose();
    super.dispose();
  }
}

/// Provides a file explorer controller to a widget subtree.
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
