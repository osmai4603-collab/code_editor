enum SortOrder { name, type, modified, size }

enum SortDirection { ascending, descending }

enum FolderPosition { first, last, mixed }

class SortConfig {
  final SortOrder order;
  final SortDirection direction;
  final FolderPosition folderPosition;
  final bool caseSensitive;

  const SortConfig({
    this.order = SortOrder.name,
    this.direction = SortDirection.ascending,
    this.folderPosition = FolderPosition.first,
    this.caseSensitive = false,
  });

  const SortConfig.defaultConfig() : this();
}
