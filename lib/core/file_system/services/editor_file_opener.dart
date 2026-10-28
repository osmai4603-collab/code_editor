import 'dart:io';

import '../../../layout/controllers/editor_controller.dart';
import 'file_system_service.dart';

class EditorFileOpener {
  final FileSystemService fileSystem;

  const EditorFileOpener(this.fileSystem);

  Future<void> open({
    required EditorDocumentsController editor,
    required String path,
    bool isPreview = false,
  }) async {
    final title = _basename(path);
    final content = await fileSystem.readFileContent(path);
    editor.openFile(
      title: title,
      path: path,
      languageId: fileSystem.resolveLanguageId(title),
      content: content,
      isPreview: isPreview,
    );
  }

  String _basename(String path) {
    final separator = path.contains(r'\') ? r'\' : Platform.pathSeparator;
    final parts = path.split(separator).where((part) => part.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }
}
