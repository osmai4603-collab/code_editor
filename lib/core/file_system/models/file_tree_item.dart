import 'dart:io';

class FileTreeItem {
  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymbolicLink;
  final bool isHidden;
  final DateTime? modifiedAt;
  final int? sizeBytes;

  FileTreeItem? parent;
  List<FileTreeItem>? _children;

  FileTreeItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isSymbolicLink = false,
    bool? isHidden,
    this.modifiedAt,
    this.sizeBytes,
    this.parent,
    List<FileTreeItem>? children,
  }) : isHidden = isHidden ?? name.startsWith('.'),
       _children = children {
    for (final child in children ?? const <FileTreeItem>[]) {
      child.parent = this;
    }
  }

  bool get isResolved => !isDirectory || _children != null;
  bool get isRoot => parent == null;
  List<FileTreeItem> get children => _children ?? const [];

  set children(List<FileTreeItem> value) {
    _children = value;
    for (final child in value) {
      child.parent = this;
    }
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  int get depth {
    var result = 0;
    var ancestor = parent;
    while (ancestor != null && !ancestor.isRoot) {
      result++;
      ancestor = ancestor.parent;
    }
    return result;
  }

  String get relativePath {
    final names = <String>[];
    var current = this;
    while (!current.isRoot) {
      names.add(current.name);
      current = current.parent!;
    }
    return names.reversed.join(Platform.pathSeparator);
  }

  FileTreeItem? find(String targetPath) {
    if (path == targetPath) return this;
    for (final child in children) {
      final found = child.find(targetPath);
      if (found != null) return found;
    }
    return null;
  }
}
