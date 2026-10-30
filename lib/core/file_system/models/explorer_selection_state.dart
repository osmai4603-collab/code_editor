import 'dart:io';

import 'file_tree_item.dart';

/// Owns the explorer's selection, clipboard, and inline-edit state.
class ExplorerSelectionState {
  String? selectedPath;
  final Set<String> selectedPaths = {};
  String? editingPath;
  String? creatingInPath;
  bool creatingIsDirectory = false;
  List<String>? clipboardPaths;
  bool clipboardIsCut = false;

  bool get hasClipboardItems => clipboardPaths?.isNotEmpty ?? false;

  List<String> get clipboardItems =>
      List.unmodifiable(clipboardPaths ?? const <String>[]);

  List<String> get selectedItems => List.unmodifiable(selectedPaths);

  void select(FileTreeItem item) {
    selectedPath = item.path;
    selectedPaths
      ..clear()
      ..add(item.path);
  }

  void toggleSelection(FileTreeItem item) {
    if (selectedPaths.add(item.path)) {
      selectedPath = item.path;
    } else {
      selectedPaths.remove(item.path);
      if (selectedPaths.isEmpty) {
        selectedPath = null;
      } else if (selectedPath == item.path) {
        selectedPath = selectedPaths.last;
      }
    }
  }

  void removePath(String path) {
    bool isDeleted(String candidate) =>
        candidate == path ||
        candidate.startsWith('$path${Platform.pathSeparator}');
    selectedPaths.removeWhere(isDeleted);
    if (selectedPath != null && isDeleted(selectedPath!)) {
      selectedPath = selectedPaths.isEmpty ? null : selectedPaths.last;
    }
  }

  List<String> normalizePaths(List<String> paths) {
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

  void remapPaths(String oldPath, String newPath) {
    String remap(String path) => path == oldPath
        ? newPath
        : path.startsWith('$oldPath${Platform.pathSeparator}')
        ? '$newPath${path.substring(oldPath.length)}'
        : path;

    final expandedSelection = selectedPaths.map(remap).toList();
    selectedPaths
      ..clear()
      ..addAll(expandedSelection);
    selectedPath = selectedPath == null ? null : remap(selectedPath!);
    if (clipboardPaths != null) {
      clipboardPaths = clipboardPaths!.map(remap).toList();
    }
  }
}
