import 'dart:io';

import '../../core/file_system/services/editor_file_opener.dart';
import '../../core/file_system/services/file_system_service.dart';
import '../controllers/editor_controller.dart';

/// Adapts the core file-opening contract to the document tab controller.
class EditorControllerFileOpener implements EditorFileOpener {
  final FileSystemService _fileSystem;
  final EditorDocumentsController _editor;

  const EditorControllerFileOpener(this._fileSystem, this._editor);

  @override
  Future<void> openFile(
    String path, {
    int? line,
    int? column,
    bool isPreview = false,
  }) async {
    final title = _basename(path);
    final content = await _fileSystem.readFileContent(path);
    _editor.openFile(
      title: title,
      path: path,
      languageId: _fileSystem.resolveLanguageId(title),
      content: content,
      isPreview: isPreview,
    );
    if (line != null || column != null) {
      _editor.requestNavigation(
        path: path,
        line: (line ?? 1) - 1,
        character: (column ?? 1) - 1,
      );
    }
  }

  @override
  Future<bool> canOpenFile(String path) async {
    if (!await _fileSystem.exists(path)) return false;
    return await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.file;
  }

  Future<void> open({
    required String path,
    bool isPreview = false,
  }) => openFile(path, isPreview: isPreview);

  String _basename(String path) {
    final separator = path.contains(r'\') ? r'\' : Platform.pathSeparator;
    final parts = path.split(separator).where((part) => part.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }
}
