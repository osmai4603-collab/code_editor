/// Immutable snapshot of the state currently shown by the file explorer.
class FileExplorerState {
  final String? rootPath;
  final Set<String> expandedPaths;
  final String? selectedPath;
  final String searchQuery;
  final Map<String, String> gitStatuses;
  final bool isLoading;
  final String? error;

  FileExplorerState({
    required this.rootPath,
    required Set<String> expandedPaths,
    required this.selectedPath,
    required this.searchQuery,
    required Map<String, String> gitStatuses,
    required this.isLoading,
    required this.error,
  }) : expandedPaths = Set.unmodifiable(expandedPaths),
       gitStatuses = Map.unmodifiable(gitStatuses);
}
