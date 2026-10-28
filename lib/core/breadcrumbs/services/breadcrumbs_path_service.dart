import '../models/breadcrumb_path_entry.dart';

class BreadcrumbsPathService {
  const BreadcrumbsPathService();

  List<BreadcrumbPathEntry> buildPath({
    required String filePath,
    String? workspacePath,
  }) {
    if (filePath.isEmpty || filePath.startsWith('file://')) return const [];

    final windowsPath =
        _isWindowsPath(filePath) ||
        (workspacePath != null && _isWindowsPath(workspacePath));
    final separator = windowsPath ? r'\' : '/';
    final file = _normalize(filePath, windowsPath);
    final workspace = workspacePath == null || workspacePath.isEmpty
        ? null
        : _normalize(workspacePath, windowsPath);
    final resolvedFile =
        workspace != null &&
            !file.isAbsolute &&
            !_isWithin(file.path, workspace.path, windowsPath, separator)
        ? _normalize(
            _join(workspace.path, file.path, separator),
            windowsPath,
          ).path
        : file.path;

    if (workspace != null &&
        _isWithin(resolvedFile, workspace.path, windowsPath, separator)) {
      final relativeParts = _relativeParts(
        resolvedFile,
        workspace.path,
        separator,
      );
      final entries = <BreadcrumbPathEntry>[
        BreadcrumbPathEntry(
          label: _basename(workspace.path, separator),
          path: workspace.path,
          directoryPath: workspace.path,
          kind: BreadcrumbPathEntryKind.workspace,
        ),
      ];
      var current = workspace.path;
      for (var index = 0; index < relativeParts.length; index++) {
        current = _join(current, relativeParts[index], separator);
        final isLast = index == relativeParts.length - 1;
        entries.add(
          BreadcrumbPathEntry(
            label: relativeParts[index],
            path: current,
            directoryPath: isLast ? _dirname(current, separator) : current,
            kind: isLast
                ? BreadcrumbPathEntryKind.file
                : BreadcrumbPathEntryKind.folder,
          ),
        );
      }
      return List.unmodifiable(entries);
    }

    final displayFile = workspace != null && !file.isAbsolute
        ? _normalize(resolvedFile, windowsPath)
        : file;
    final parts = displayFile.parts;
    if (parts.isEmpty) {
      if (displayFile.root.isEmpty) return const [];
      return [
        BreadcrumbPathEntry(
          label: displayFile.root,
          path: displayFile.root,
          directoryPath: displayFile.root,
          kind: BreadcrumbPathEntryKind.root,
        ),
      ];
    }
    final entries = <BreadcrumbPathEntry>[];
    var current = displayFile.root;
    if (displayFile.root.isNotEmpty) {
      entries.add(
        BreadcrumbPathEntry(
          label: displayFile.root,
          path: displayFile.root,
          directoryPath: displayFile.root,
          kind: BreadcrumbPathEntryKind.root,
        ),
      );
    }
    for (var index = 0; index < parts.length; index++) {
      current = current.isEmpty
          ? parts[index]
          : _join(current, parts[index], separator);
      final isLast = index == parts.length - 1;
      entries.add(
        BreadcrumbPathEntry(
          label: parts[index],
          path: current,
          directoryPath: isLast ? _dirname(current, separator) : current,
          kind: isLast
              ? BreadcrumbPathEntryKind.file
              : BreadcrumbPathEntryKind.folder,
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  bool _isWithin(String path, String root, bool windowsPath, String separator) {
    final comparablePath = windowsPath ? path.toLowerCase() : path;
    final comparableRoot = windowsPath ? root.toLowerCase() : root;
    return comparablePath == comparableRoot ||
        comparablePath.startsWith(
          comparableRoot.endsWith(separator)
              ? comparableRoot
              : '$comparableRoot$separator',
        );
  }

  List<String> _relativeParts(String path, String root, String separator) {
    if (path == root) return const [];
    final start = root.endsWith(separator) ? root.length : root.length + 1;
    return path
        .substring(start)
        .split(separator)
        .where((part) => part.isNotEmpty)
        .toList();
  }

  _NormalizedPath _normalize(String path, bool windowsPath) {
    final separator = windowsPath ? r'\' : '/';
    final source = windowsPath ? path.replaceAll('/', r'\') : path;
    final isUnc = windowsPath && source.startsWith(r'\\');
    final drive = windowsPath
        ? RegExp(r'^[a-zA-Z]:').firstMatch(source)?.group(0)
        : null;
    final isAbsolute = source.startsWith(separator) || drive != null;
    final root = isUnc
        ? r'\\'
        : drive != null
        ? '$drive$separator'
        : source.startsWith(separator)
        ? separator
        : '';
    final remainder = drive != null
        ? source.substring(drive.length).replaceFirst(RegExp(r'^[\\/]'), '')
        : isUnc
        ? source.substring(2)
        : source.replaceFirst(RegExp(r'^[\\/]'), '');
    final parts = <String>[];
    for (final part in remainder.split(separator)) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty && parts.last != '..') {
          parts.removeLast();
        } else if (!isAbsolute) {
          parts.add(part);
        }
      } else {
        parts.add(part);
      }
    }
    if (isUnc && parts.length >= 2) {
      final uncRoot = '$root${parts.take(2).join(separator)}';
      return _NormalizedPath(
        path: parts.length == 2
            ? uncRoot
            : '$uncRoot$separator${parts.skip(2).join(separator)}',
        root: uncRoot,
        parts: parts.skip(2).toList(),
        isAbsolute: true,
      );
    }
    final normalized = root.isEmpty
        ? parts.join(separator)
        : parts.isEmpty
        ? root
        : '$root${root.endsWith(separator) ? '' : separator}${parts.join(separator)}';
    return _NormalizedPath(
      path: normalized,
      root: root,
      parts: parts,
      isAbsolute: isAbsolute,
    );
  }

  bool _isWindowsPath(String path) =>
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path) || path.startsWith(r'\\');

  String _basename(String path, String separator) {
    final trimmed = path.endsWith(separator) && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    if (trimmed.isEmpty || trimmed == separator) return trimmed;
    if (RegExp(r'^[a-zA-Z]:\\?$').hasMatch(trimmed)) return trimmed;
    final index = trimmed.lastIndexOf(separator);
    return index == -1 ? trimmed : trimmed.substring(index + 1);
  }

  String _dirname(String path, String separator) {
    final index = path.lastIndexOf(separator);
    if (index < 0) return '';
    if (index == 0) return separator;
    if (RegExp(r'^[a-zA-Z]:\\$').hasMatch(path)) return path;
    if (index == 2 && RegExp(r'^[a-zA-Z]:').hasMatch(path)) {
      return path.substring(0, 3);
    }
    return path.substring(0, index);
  }

  String _join(String parent, String child, String separator) {
    if (parent.isEmpty) return child;
    if (parent.endsWith(separator)) return '$parent$child';
    return '$parent$separator$child';
  }
}

class _NormalizedPath {
  final String path;
  final String root;
  final List<String> parts;
  final bool isAbsolute;

  const _NormalizedPath({
    required this.path,
    required this.root,
    required this.parts,
    required this.isAbsolute,
  });
}
