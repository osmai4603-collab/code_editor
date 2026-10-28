enum BreadcrumbPathEntryKind { workspace, root, folder, file }

class BreadcrumbPathEntry {
  final String label;
  final String path;
  final String directoryPath;
  final BreadcrumbPathEntryKind kind;

  const BreadcrumbPathEntry({
    required this.label,
    required this.path,
    required this.directoryPath,
    required this.kind,
  });

  bool get isFile => kind == BreadcrumbPathEntryKind.file;
}
