import 'dart:io';

import '../../languages/definitions/built_in_languages.dart';
import '../models/file_tree_item.dart';

class FileSystemService {
  static final _languageRegistry = createBuiltInLanguageRegistry();
  static const excludedDirectoryNames = {
    '.git',
    '.dart_tool',
    'build',
    '.idea',
    '.vscode',
    'node_modules',
    '.DS_Store',
  };

  Future<List<FileTreeItem>> listDirectory(String path) async {
    final directory = Directory(path);
    final entries = await directory.list(followLinks: false).toList();
    return Future.wait(entries.map(_itemFor));
  }

  Future<List<String>> searchPaths(
    String rootPath,
    String query, {
    bool showHiddenFiles = false,
  }) async {
    final normalizedQuery = query.toLowerCase();
    final results = <String>[];

    Future<void> visit(Directory directory) async {
      await for (final entity in directory.list(followLinks: false)) {
        final name = _basename(entity.path);
        if (excludedDirectoryNames.contains(name) ||
            (!showHiddenFiles && name.startsWith('.'))) {
          continue;
        }

        if (name.toLowerCase().contains(normalizedQuery)) {
          results.add(entity.path);
        }

        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory) {
          await visit(Directory(entity.path));
        }
      }
    }

    await visit(Directory(rootPath));
    return results;
  }

  Future<String> readFileContent(String path) => File(path).readAsString();

  Future<bool> exists(String path) => FileSystemEntity.type(
    path,
    followLinks: false,
  ).then((type) => type != FileSystemEntityType.notFound);

  Future<FileStat> stat(String path) => FileStat.stat(path);

  Future<FileTreeItem> createFile(String path, {String content = ''}) async {
    final file = File(path);
    await file.create();
    if (content.isNotEmpty) await file.writeAsString(content);
    return _itemFor(file);
  }

  Future<FileTreeItem> createDirectory(String path) async {
    final directory = Directory(path);
    await directory.create();
    return _itemFor(directory);
  }

  Future<void> delete(String path, {bool recursive = false}) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('Path does not exist', path);
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: recursive);
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else {
      await File(path).delete();
    }
  }

  Future<FileTreeItem> rename(String oldPath, String newName) async {
    if (newName.trim().isEmpty ||
        newName == '.' ||
        newName == '..' ||
        newName.contains(Platform.pathSeparator) ||
        (Platform.isWindows && newName.contains('/'))) {
      throw FileSystemException('Invalid file name', newName);
    }
    final destination = _join(_dirname(oldPath), newName);
    if (await exists(destination)) {
      throw FileSystemException('Destination already exists', destination);
    }
    return _moveEntity(oldPath, destination);
  }

  Future<FileTreeItem> move(String sourcePath, String targetDirectory) async {
    final destination = _join(targetDirectory, _basename(sourcePath));
    _ensureMoveAllowed(sourcePath, destination);
    if (await exists(destination)) {
      throw FileSystemException('Destination already exists', destination);
    }
    return _moveEntity(sourcePath, destination);
  }

  Future<FileTreeItem> copy(String sourcePath, String targetDirectory) async {
    final destination = _join(targetDirectory, _basename(sourcePath));
    _ensureMoveAllowed(sourcePath, destination);
    if (await exists(destination)) {
      throw FileSystemException('Destination already exists', destination);
    }
    final type = await FileSystemEntity.type(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _copyDirectory(Directory(sourcePath), Directory(destination));
    } else if (type == FileSystemEntityType.link) {
      final target = await Link(sourcePath).target();
      await Link(destination).create(target);
    } else if (type == FileSystemEntityType.file) {
      await File(sourcePath).copy(destination);
    } else {
      throw FileSystemException('Source does not exist', sourcePath);
    }
    return _itemFor(
      FileSystemEntity.isDirectorySync(destination)
          ? Directory(destination)
          : File(destination),
    );
  }

  String resolveLanguageId(String filename) {
    return _languageRegistry.resolveLanguageId(filename);
  }

  Future<FileTreeItem> _itemFor(FileSystemEntity entity) async {
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    final isLink = type == FileSystemEntityType.link;
    final stat = isLink ? null : await entity.stat();
    return FileTreeItem(
      name: _basename(entity.path),
      path: entity.path,
      isDirectory: type == FileSystemEntityType.directory,
      isSymbolicLink: type == FileSystemEntityType.link,
      modifiedAt: stat?.modified,
      sizeBytes: type == FileSystemEntityType.directory || isLink
          ? null
          : stat?.size,
    );
  }

  Future<FileTreeItem> _moveEntity(String source, String destination) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      return _itemFor(await Directory(source).rename(destination));
    }
    if (type == FileSystemEntityType.link) {
      return _itemFor(await Link(source).rename(destination));
    }
    if (type == FileSystemEntityType.file) {
      return _itemFor(await File(source).rename(destination));
    }
    throw FileSystemException('Source does not exist', source);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create();
    await for (final entity in source.list(followLinks: false)) {
      final target = _join(destination.path, _basename(entity.path));
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(entity.path), Directory(target));
      } else if (type == FileSystemEntityType.link) {
        await Link(target).create(await Link(entity.path).target());
      } else if (type == FileSystemEntityType.file) {
        await File(entity.path).copy(target);
      }
    }
  }

  void _ensureMoveAllowed(String source, String destination) {
    final normalizedSource = _normalize(source);
    final normalizedDestination = _normalize(destination);
    if (normalizedSource == normalizedDestination ||
        normalizedDestination.startsWith(
          '$normalizedSource${Platform.pathSeparator}',
        )) {
      throw FileSystemException(
        'Cannot move or copy a directory into itself',
        source,
      );
    }
  }

  String _normalize(String path) {
    final absolute = Directory(path).absolute.path;
    final separator = Platform.pathSeparator;
    return absolute.length > 1 && absolute.endsWith(separator)
        ? absolute.substring(0, absolute.length - 1)
        : absolute;
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final end = normalized.endsWith('/')
        ? normalized.length - 1
        : normalized.length;
    return normalized.substring(normalized.lastIndexOf('/', end - 1) + 1, end);
  }

  String _dirname(String path) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    if (separatorIndex <= 0) return Platform.pathSeparator;
    return path.substring(0, separatorIndex);
  }

  String _join(String directory, String name) =>
      directory.endsWith(Platform.pathSeparator)
      ? '$directory$name'
      : '$directory${Platform.pathSeparator}$name';
}
