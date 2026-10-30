import 'file_system_service.dart';

/// Searches workspace paths and computes the ancestors needed to reveal them.
class ExplorerSearchService {
  final FileSystemService _fileSystemService;

  const ExplorerSearchService(this._fileSystemService);

  Future<ExplorerSearchResult> search(
    String rootPath,
    String query, {
    bool showHiddenFiles = false,
  }) async {
    final matches = await _fileSystemService.searchPaths(
      rootPath,
      query,
      showHiddenFiles: showHiddenFiles,
    );
    final ancestors = <String>{};
    for (final match in matches) {
      var parent = _dirname(match);
      while (parent != rootPath &&
          parent.startsWith('$rootPath${_separator(match)}')) {
        ancestors.add(parent);
        parent = _dirname(parent);
      }
    }
    return ExplorerSearchResult(
      matches: Set.unmodifiable(matches),
      ancestors: Set.unmodifiable(ancestors),
    );
  }

  String _separator(String path) => path.contains(r'\') ? r'\' : '/';

  String _dirname(String path) {
    final separator = _separator(path);
    final index = path.lastIndexOf(separator);
    return index <= 0 ? separator : path.substring(0, index);
  }
}

/// Search matches and their ancestor directories.
class ExplorerSearchResult {
  final Set<String> matches;
  final Set<String> ancestors;

  ExplorerSearchResult({
    required Set<String> matches,
    required Set<String> ancestors,
  }) : matches = Set.unmodifiable(matches),
       ancestors = Set.unmodifiable(ancestors);
}
