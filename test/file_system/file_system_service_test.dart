import 'dart:io';

import 'package:code_editor/core/file_system/models/file_tree_item.dart';
import 'package:code_editor/core/file_system/services/file_system_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late FileSystemService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('code_editor_fs_');
    service = FileSystemService();
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('tree items track parent, depth, relative path, and lookup', () {
    final root = FileTreeItem(
      name: 'project',
      path: tempDirectory.path,
      isDirectory: true,
      children: [
        FileTreeItem(
          name: 'lib',
          path: '${tempDirectory.path}${Platform.pathSeparator}lib',
          isDirectory: true,
          children: [
            FileTreeItem(
              name: 'main.dart',
              path:
                  '${tempDirectory.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
              isDirectory: false,
            ),
          ],
        ),
      ],
    );
    final file = root.find(
      '${tempDirectory.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
    )!;

    expect(file.depth, 1);
    expect(file.relativePath, 'lib${Platform.pathSeparator}main.dart');
    expect(root.find(tempDirectory.path), same(root));
    expect(root.children.single.parent, same(root));
  });

  test(
    'listDirectory reads only one level and provides filesystem metadata',
    () async {
      final nested = Directory('${tempDirectory.path}/nested');
      await nested.create();
      final file = File('${tempDirectory.path}/hello.dart');
      await file.writeAsString('void main() {}');

      final items = await service.listDirectory(tempDirectory.path);
      final directoryItem = items.singleWhere((item) => item.name == 'nested');
      final fileItem = items.singleWhere((item) => item.name == 'hello.dart');

      expect(directoryItem.isDirectory, isTrue);
      expect(directoryItem.isResolved, isFalse);
      expect(fileItem.isDirectory, isFalse);
      expect(fileItem.extension, 'dart');
      expect(fileItem.sizeBytes, greaterThan(0));
      expect(await service.readFileContent(file.path), 'void main() {}');
    },
  );

  test(
    'creates, renames, copies, moves, and recursively deletes entries',
    () async {
      final source = Directory('${tempDirectory.path}/source');
      final target = Directory('${tempDirectory.path}/target');
      await source.create();
      await target.create();
      final created = await service.createFile(
        '${source.path}/example.py',
        content: 'print("ok")',
      );
      expect(created.name, 'example.py');

      final renamed = await service.rename(created.path, 'renamed.py');
      expect(await File(renamed.path).readAsString(), 'print("ok")');

      final copied = await service.copy(renamed.path, target.path);
      expect(await File(copied.path).exists(), isTrue);
      await service.delete(copied.path);

      final moved = await service.move(renamed.path, target.path);
      expect(await File(moved.path).exists(), isTrue);
      expect(await File(renamed.path).exists(), isFalse);

      await service.delete(target.path, recursive: true);
      expect(await target.exists(), isFalse);
    },
  );

  test(
    'rejects name and destination conflicts and copying into descendants',
    () async {
      final folder = Directory('${tempDirectory.path}/folder');
      await folder.create();
      final file = File('${tempDirectory.path}/same.txt');
      await file.writeAsString('one');
      await File('${tempDirectory.path}/existing.txt').writeAsString('two');

      await expectLater(
        service.rename(file.path, 'existing.txt'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        service.rename(file.path, '../outside.txt'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        service.copy(folder.path, '${folder.path}/child'),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('resolves common language identifiers', () {
    expect(service.resolveLanguageId('main.DART'), 'dart');
    expect(service.resolveLanguageId('app.tsx'), 'typescript');
    expect(service.resolveLanguageId('notes.txt'), 'plaintext');
  });
}
