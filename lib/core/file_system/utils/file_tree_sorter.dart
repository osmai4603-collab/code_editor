import '../models/file_tree_item.dart';
import '../models/sort_config.dart';

/// Sorts file tree entries according to the explorer's configured order.
class FileTreeSorter {
  const FileTreeSorter();

  List<FileTreeItem> sort(
    Iterable<FileTreeItem> children,
    SortConfig config,
  ) {
    final result = children.toList();
    result.sort((a, b) => _compare(a, b, config));
    return result;
  }

  int _compare(FileTreeItem a, FileTreeItem b, SortConfig config) {
    if (config.folderPosition != FolderPosition.mixed &&
        a.isDirectory != b.isDirectory) {
      final foldersFirst = config.folderPosition == FolderPosition.first;
      return a.isDirectory == foldersFirst ? -1 : 1;
    }

    final comparison = switch (config.order) {
      SortOrder.name => _compareName(a.name, b.name, config.caseSensitive),
      SortOrder.type => _compareType(a, b),
      SortOrder.modified => (a.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      SortOrder.size => (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0),
    };
    return config.direction == SortDirection.ascending
        ? comparison
        : -comparison;
  }

  int _compareName(String left, String right, bool caseSensitive) =>
      (caseSensitive ? left : left.toLowerCase()).compareTo(
        caseSensitive ? right : right.toLowerCase(),
      );

  int _compareType(FileTreeItem a, FileTreeItem b) {
    final extensionComparison = a.extension.compareTo(b.extension);
    return extensionComparison == 0
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : extensionComparison;
  }
}
