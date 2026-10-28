import 'dart:async';
import 'dart:io';

import 'package:code_editor/core/file_system/controllers/file_explorer_controller.dart';
import 'package:code_editor/core/file_system/models/sort_config.dart';
import 'package:code_editor/core/file_system/services/file_system_service.dart';
import 'package:code_editor/core/file_system/services/file_watcher_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late FileExplorerController controller;
  late FileWatcherService watcher;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'code_editor_explorer_',
    );
    watcher = FileWatcherService();
    controller = FileExplorerController(
      fileService: FileSystemService(),
      watcherService: watcher,
      persistState: false,
    );
  });

  tearDown(() async {
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('opens a workspace and lazily loads expanded directories', () async {
    final nested = Directory('${tempDirectory.path}/nested');
    await nested.create();
    await File('${nested.path}/item.txt').writeAsString('text');

    await controller.openWorkspace(tempDirectory.path);
    final folder = controller.root!.children.single;
    expect(folder.isResolved, isFalse);
    expect(controller.getVisibleItems().map((item) => item.name), ['nested']);

    await controller.toggleExpand(folder);
    expect(folder.isResolved, isTrue);
    expect(controller.getVisibleItems().map((item) => item.name), [
      'nested',
      'item.txt',
    ]);
  });

  test('sorts folders first and filters hidden and excluded entries', () async {
    await Directory('${tempDirectory.path}/z-folder').create();
    await File('${tempDirectory.path}/b.txt').writeAsString('');
    await File('${tempDirectory.path}/.hidden').writeAsString('');
    await Directory('${tempDirectory.path}/.git').create();
    await controller.openWorkspace(tempDirectory.path);

    expect(controller.getVisibleItems().map((item) => item.name), [
      'z-folder',
      'b.txt',
    ]);
    controller.updateSortConfig(
      const SortConfig(
        direction: SortDirection.descending,
        folderPosition: FolderPosition.mixed,
      ),
    );
    expect(controller.getVisibleItems().map((item) => item.name), [
      'z-folder',
      'b.txt',
    ]);
    controller.setShowHiddenFiles(true);
    expect(controller.getVisibleItems().map((item) => item.name), [
      'z-folder',
      'b.txt',
      '.hidden',
    ]);
  });

  test(
    'updates the tree after create, rename, and delete operations',
    () async {
      await controller.openWorkspace(tempDirectory.path);
      final created = await controller.createFile(
        tempDirectory.path,
        'new.txt',
      );
      expect(controller.findItem(created.path), isNotNull);

      await controller.rename(created.path, 'renamed.txt');
      final renamedPath = '${tempDirectory.path}/renamed.txt';
      expect(controller.findItem(renamedPath), isNotNull);

      await controller.delete([renamedPath]);
      expect(controller.findItem(renamedPath), isNull);
    },
  );

  test(
    'refreshes the workspace when the file watcher reports changes',
    () async {
      await controller.openWorkspace(tempDirectory.path);
      final changed = Completer<void>();
      controller.addListener(() {
        if (controller.findItem('${tempDirectory.path}/external.txt') != null &&
            !changed.isCompleted) {
          changed.complete();
        }
      });

      await File(
        '${tempDirectory.path}/external.txt',
      ).writeAsString('external');
      await changed.future.timeout(const Duration(seconds: 4));
      expect(
        controller.findItem('${tempDirectory.path}/external.txt'),
        isNotNull,
      );
    },
  );
}
