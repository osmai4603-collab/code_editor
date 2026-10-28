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

  test('flattens a workspace containing at least 1000 files', () async {
    await Future.wait(
      List.generate(
        1000,
        (index) => File('${tempDirectory.path}/file_$index.dart').create(),
      ),
    );
    await controller.openWorkspace(tempDirectory.path);

    final visibleItems = controller.getVisibleItems();
    expect(visibleItems, hasLength(1000));
    expect(controller.getVisibleItems(), same(visibleItems));
  });

  test('sorts folders first and filters hidden and excluded entries', () async {
    await Directory('${tempDirectory.path}/z-folder').create();
    await File('${tempDirectory.path}/b.txt').writeAsString('');
    await File('${tempDirectory.path}/c.txt').writeAsString('');
    await File('${tempDirectory.path}/.hidden').writeAsString('');
    await Directory('${tempDirectory.path}/.git').create();
    await controller.openWorkspace(tempDirectory.path);

    expect(controller.getVisibleItems().map((item) => item.name), [
      'z-folder',
      'b.txt',
      'c.txt',
    ]);
    controller.updateSortConfig(
      const SortConfig(
        direction: SortDirection.descending,
        folderPosition: FolderPosition.mixed,
      ),
    );
    expect(controller.getVisibleItems().map((item) => item.name), [
      'z-folder',
      'c.txt',
      'b.txt',
    ]);
    controller.setShowHiddenFiles(true);
    expect(controller.getVisibleItems().map((item) => item.name), [
      'z-folder',
      'c.txt',
      'b.txt',
      '.hidden',
    ]);
  });

  test('sorts and filters entries shown by breadcrumb navigation', () async {
    await Directory('${tempDirectory.path}/z-folder').create();
    await File('${tempDirectory.path}/b.txt').writeAsString('');
    await File('${tempDirectory.path}/a.txt').writeAsString('');
    await File('${tempDirectory.path}/.hidden').writeAsString('');
    await Directory('${tempDirectory.path}/.git').create();

    final entries = await controller.listDirectoryForNavigation(
      tempDirectory.path,
    );

    expect(entries.map((item) => item.name), ['z-folder', 'a.txt', 'b.txt']);
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

  test(
    'search finds matching files in folders that have not been expanded',
    () async {
      final nested = Directory('${tempDirectory.path}/lib/core');
      await nested.create(recursive: true);
      await File('${nested.path}/target_file.dart').writeAsString('');
      await File('${nested.path}/other.dart').writeAsString('');
      await controller.openWorkspace(tempDirectory.path);

      final completed = Completer<void>();
      controller.addListener(() {
        final names = controller.getVisibleItems().map((item) => item.name);
        if (!controller.isSearching && names.contains('target_file.dart')) {
          if (!completed.isCompleted) completed.complete();
        }
      });
      controller.setSearchQuery('target_file');

      await completed.future.timeout(const Duration(seconds: 4));
      expect(controller.getVisibleItems().map((item) => item.name), [
        'lib',
        'core',
        'target_file.dart',
      ]);
      expect(controller.findItem('${nested.path}/other.dart'), isNotNull);
    },
  );

  test('search supports filtering and highlighting matching paths', () async {
    await File('${tempDirectory.path}/matching_file.dart').writeAsString('');
    await File('${tempDirectory.path}/another_file.dart').writeAsString('');
    await controller.openWorkspace(tempDirectory.path);

    final completed = Completer<void>();
    controller.addListener(() {
      if (!controller.isSearching &&
          controller.isSearchMatch(
            '${tempDirectory.path}/matching_file.dart',
          ) &&
          !completed.isCompleted) {
        completed.complete();
      }
    });
    controller.setSearchQuery('matching');
    await completed.future.timeout(const Duration(seconds: 4));

    expect(controller.getVisibleItems().map((item) => item.name), [
      'matching_file.dart',
    ]);
    controller.setSearchMode(ExplorerSearchMode.highlight);
    expect(controller.getVisibleItems().map((item) => item.name), [
      'another_file.dart',
      'matching_file.dart',
    ]);
    expect(
      controller.isSearchMatch('${tempDirectory.path}/matching_file.dart'),
      isTrue,
    );
    expect(
      controller.isSearchMatch('${tempDirectory.path}/another_file.dart'),
      isFalse,
    );
  });

  test('reports Git status for files and directories', () async {
    Future<void> runGit(List<String> arguments) async {
      final result = await Process.run('git', [
        '-C',
        tempDirectory.path,
        ...arguments,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }

    await runGit(['init', '-q']);
    await runGit(['config', 'user.email', 'explorer-test@example.com']);
    await runGit(['config', 'user.name', 'Explorer Test']);
    final tracked = File('${tempDirectory.path}/src/tracked file.txt');
    await tracked.parent.create();
    await tracked.writeAsString('original');
    final deleted = File('${tempDirectory.path}/src/deleted.txt');
    await deleted.writeAsString('to delete');
    final renamed = File('${tempDirectory.path}/src/rename source.txt');
    await renamed.writeAsString('to rename');
    await runGit(['add', '.']);
    await runGit(['commit', '-q', '-m', 'Initial commit']);

    await tracked.writeAsString('modified');
    await deleted.delete();
    await runGit(['mv', 'src/rename source.txt', 'src/renamed target.txt']);
    final added = File('${tempDirectory.path}/src/added.txt');
    await added.writeAsString('added');
    await runGit(['add', 'src/added.txt']);
    final untracked = File('${tempDirectory.path}/src/new file.txt');
    await untracked.writeAsString('new');
    await controller.openWorkspace(tempDirectory.path);
    await controller.refreshGitStatus();

    expect(controller.gitStatusFor(tracked.path), 'M');
    expect(controller.gitStatusFor(deleted.path), 'D');
    expect(
      controller.gitStatusFor('${tempDirectory.path}/src/renamed target.txt'),
      'R',
    );
    expect(controller.gitStatusFor(added.path), 'A');
    expect(controller.gitStatusFor(untracked.path), 'U');
    expect(
      controller.gitStatusFor('${tempDirectory.path}/src', isDirectory: true),
      'M',
    );
  });

  test(
    'refreshes the tree after a partially successful multi-delete',
    () async {
      final existing = File('${tempDirectory.path}/first.txt');
      await existing.writeAsString('');
      await controller.openWorkspace(tempDirectory.path);
      final missing = '${tempDirectory.path}/missing.txt';

      await expectLater(
        controller.delete([existing.path, missing]),
        throwsA(isA<FileSystemException>()),
      );
      expect(controller.findItem(existing.path), isNull);
      expect(await existing.exists(), isFalse);
    },
  );

  test(
    'refreshes both folders after a partially successful multi-move',
    () async {
      final target = Directory('${tempDirectory.path}/target');
      await target.create();
      final first = File('${tempDirectory.path}/first.txt');
      await first.writeAsString('');
      await File('${target.path}/second.txt').writeAsString('');
      final second = File('${tempDirectory.path}/second.txt');
      await second.writeAsString('');
      await controller.openWorkspace(tempDirectory.path);
      await controller.toggleExpand(controller.findItem(target.path)!);

      await expectLater(
        controller.move([first.path, second.path], target.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(controller.findItem('${target.path}/first.txt'), isNotNull);
      expect(controller.findItem(first.path), isNull);
      expect(controller.findItem(second.path), isNotNull);
    },
  );
}
