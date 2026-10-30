import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/file_system/services/editor_file_opener.dart';
import 'package:code_editor/core/file_system/services/file_system_service.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/layout/services/editor_file_opener.dart';

void main() {
  late Directory directory;
  late EditorDocumentsController documents;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('editor-file-opener-');
    documents = EditorDocumentsController();
  });

  tearDown(() async {
    documents.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'opens files with shared language detection and avoids duplicate tabs',
    () async {
      final path = '${directory.path}${Platform.pathSeparator}main.dart';
      await File(path).writeAsString('void main() {}');
      final EditorFileOpener opener = EditorControllerFileOpener(
        FileSystemService(),
        documents,
      );

      await opener.openFile(path);
      await File(path).writeAsString('changed on disk');
      await opener.openFile(path);

      expect(documents.tabs, hasLength(1));
      expect(documents.activeTab?.title, 'main.dart');
      expect(documents.activeTab?.languageId, 'dart');
      expect(documents.activeTab?.content, 'void main() {}');
      expect(await opener.canOpenFile(path), isTrue);
      expect(await opener.canOpenFile('${directory.path}/missing.dart'), isFalse);
    },
  );
}
