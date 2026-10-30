import 'package:code_editor/core/file_system/models/file_tree_item.dart';
import 'package:code_editor/core/file_system/models/sort_config.dart';
import 'package:code_editor/core/file_system/utils/file_tree_sorter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sorts folders first and honors configured order and direction', () {
    final items = [
      FileTreeItem(name: 'z.txt', path: '/z.txt', isDirectory: false),
      FileTreeItem(name: 'a', path: '/a', isDirectory: true),
      FileTreeItem(name: 'a.txt', path: '/a.txt', isDirectory: false),
    ];

    final sorter = const FileTreeSorter();
    expect(
      sorter
          .sort(items, const SortConfig.defaultConfig())
          .map((item) => item.name),
      ['a', 'a.txt', 'z.txt'],
    );
    expect(
      sorter
          .sort(
            items,
            const SortConfig(
              direction: SortDirection.descending,
              folderPosition: FolderPosition.mixed,
            ),
          )
          .map((item) => item.name),
      ['z.txt', 'a.txt', 'a'],
    );
  });
}
