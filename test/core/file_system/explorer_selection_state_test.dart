import 'package:code_editor/core/file_system/models/explorer_selection_state.dart';
import 'package:code_editor/core/file_system/models/file_tree_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks toggled selection and normalizes nested paths', () {
    final selection = ExplorerSelectionState();
    final first = FileTreeItem(
      name: 'folder',
      path: '/workspace/folder',
      isDirectory: true,
    );
    final second = FileTreeItem(
      name: 'item.dart',
      path: '/workspace/folder/item.dart',
      isDirectory: false,
    );

    selection.select(first);
    selection.toggleSelection(second);
    expect(selection.selectedItems, [first.path, second.path]);
    expect(selection.normalizePaths([second.path, first.path]), [first.path]);

    selection.toggleSelection(first);
    expect(selection.selectedPath, second.path);
    selection.removePath('/workspace/folder');
    expect(selection.selectedPath, isNull);
  });

  test('remaps selected and clipboard paths after a move', () {
    final selection = ExplorerSelectionState()
      ..selectedPath = '/workspace/old/item.dart'
      ..selectedPaths.add('/workspace/old/item.dart')
      ..clipboardPaths = ['/workspace/old/item.dart'];

    selection.remapPaths('/workspace/old', '/workspace/new');

    expect(selection.selectedPath, '/workspace/new/item.dart');
    expect(selection.selectedItems, ['/workspace/new/item.dart']);
    expect(selection.clipboardItems, ['/workspace/new/item.dart']);
  });
}
