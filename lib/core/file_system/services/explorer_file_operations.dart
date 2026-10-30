// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import '../models/file_tree_item.dart';
import 'file_system_service.dart';

/// Coordinates explorer file mutations with tree refresh and state callbacks.
class ExplorerFileOperations {
  final FileSystemService _fileSystemService;
  final Future<void> Function(String path) _refreshDirectory;
  final Future<void> Function(List<String> paths) _refreshParents;
  final void Function(String path) _removeSelection;
  final void Function(String oldPath, String newPath) _remapPaths;
  final void Function(String error) _reportPartialFailure;
  final void Function() _scheduleGitStatusRefresh;

  const ExplorerFileOperations({
    required FileSystemService fileSystemService,
    required Future<void> Function(String path) refreshDirectory,
    required Future<void> Function(List<String> paths) refreshParents,
    required void Function(String path) removeSelection,
    required void Function(String oldPath, String newPath) remapPaths,
    required void Function(String error) reportPartialFailure,
    required void Function() scheduleGitStatusRefresh,
  }) : _fileSystemService = fileSystemService,
       _refreshDirectory = refreshDirectory,
       _refreshParents = refreshParents,
       _removeSelection = removeSelection,
       _remapPaths = remapPaths,
       _reportPartialFailure = reportPartialFailure,
       _scheduleGitStatusRefresh = scheduleGitStatusRefresh;

  Future<FileTreeItem> createFile(String parentPath, String name) async {
    final result = await _fileSystemService.createFile(_join(parentPath, name));
    await _refreshDirectory(parentPath);
    _scheduleGitStatusRefresh();
    return result;
  }

  Future<FileTreeItem> createDirectory(String parentPath, String name) async {
    final result = await _fileSystemService.createDirectory(
      _join(parentPath, name),
    );
    await _refreshDirectory(parentPath);
    _scheduleGitStatusRefresh();
    return result;
  }

  Future<void> delete(List<String> paths) async {
    try {
      for (final path in paths) {
        await _fileSystemService.delete(path, recursive: true);
        _removeSelection(path);
      }
    } catch (_) {
      try {
        await _refreshParents(paths);
      } catch (refreshError) {
        _reportPartialFailure(
          'Unable to refresh after a partial delete: $refreshError',
        );
      }
      _scheduleGitStatusRefresh();
      rethrow;
    }
    await _refreshParents(paths);
    _scheduleGitStatusRefresh();
  }

  Future<void> rename(String path, String newName) async {
    final result = await _fileSystemService.rename(path, newName);
    _remapPaths(path, result.path);
    await _refreshDirectory(_dirname(path));
    _scheduleGitStatusRefresh();
  }

  Future<void> move(List<String> paths, String targetDirectory) async {
    try {
      for (final path in paths) {
        final result = await _fileSystemService.move(path, targetDirectory);
        _remapPaths(path, result.path);
      }
    } catch (_) {
      try {
        await _refreshParents(paths);
        await _refreshDirectory(targetDirectory);
      } catch (refreshError) {
        _reportPartialFailure(
          'Unable to refresh after a partial move: $refreshError',
        );
      }
      _scheduleGitStatusRefresh();
      rethrow;
    }
    await _refreshParents(paths);
    await _refreshDirectory(targetDirectory);
    _scheduleGitStatusRefresh();
  }

  Future<void> copy(List<String> paths, String targetDirectory) async {
    try {
      for (final path in paths) {
        await _fileSystemService.copy(path, targetDirectory);
      }
    } catch (_) {
      try {
        await _refreshDirectory(targetDirectory);
      } catch (refreshError) {
        _reportPartialFailure(
          'Unable to refresh after a partial copy: $refreshError',
        );
      }
      _scheduleGitStatusRefresh();
      rethrow;
    }
    await _refreshDirectory(targetDirectory);
    _scheduleGitStatusRefresh();
  }

  String _dirname(String path) {
    final index = path.lastIndexOf(Platform.pathSeparator);
    return index <= 0 ? Platform.pathSeparator : path.substring(0, index);
  }

  String _join(String directory, String name) {
    return directory.endsWith(Platform.pathSeparator)
        ? '$directory$name'
        : '$directory${Platform.pathSeparator}$name';
  }
}
