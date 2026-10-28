import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/file_system/controllers/file_explorer_controller.dart';
import '../../../core/file_system/models/file_tree_item.dart';
import '../../../core/file_system/services/editor_file_opener.dart';
import '../../../core/file_system/services/file_system_service.dart';
import '../../../layout/controllers/editor_controller.dart';
import '../../../layout/controllers/lsp_and_execution_scope.dart';
import 'dialogs/delete_confirm_dialog.dart';
import 'dialogs/move_conflict_dialog.dart';
import 'widgets/file_tree_tile.dart';
import 'widgets/inline_rename_field.dart';

class ExplorerTree extends StatefulWidget {
  const ExplorerTree({super.key});

  @override
  State<ExplorerTree> createState() => _ExplorerTreeState();
}

class _ExplorerTreeState extends State<ExplorerTree> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<String, Timer> _hoverTimers = {};
  final FileSystemService _fileService = FileSystemService();
  late final EditorFileOpener _fileOpener = EditorFileOpener(_fileService);
  bool _isRevealing = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    for (final timer in _hoverTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = FileExplorerScope.of(context);
    final editor = EditorDocumentsScope.of(context);
    final diagnostics = DiagnosticsScope.of(context);
    final items = controller.getVisibleItems();
    final rows = <_TreeRow>[];
    final creatingPath = controller.creatingInPath;
    if (creatingPath == controller.root?.path) {
      rows.add(_TreeRow.create(0));
    }
    for (final item in items) {
      rows.add(_TreeRow.item(item));
      if (item.path == creatingPath) rows.add(_TreeRow.create(item.depth + 1));
    }

    _revealSelection(controller, rows);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) =>
          _onKeyEvent(context, event, controller, editor, items),
      child: Scrollbar(
        controller: _scrollController,
        thickness: 6,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: rows.length,
          itemExtent: 22,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row.isCreate) {
              return Padding(
                padding: EdgeInsets.only(left: 4 + row.depth * 16, right: 6),
                child: InlineRenameField(
                  key: ValueKey('new-${controller.creatingInPath}'),
                  initialName: '',
                  onSubmit: (name) => _create(context, controller, name),
                  onCancel: controller.cancelEdit,
                ),
              );
            }

            final item = row.item!;
            final fileDiagnostics = diagnostics.getForUri(
              Uri.file(item.path).toString(),
            );
            final dirty = editor.tabs.any(
              (tab) => tab.path == item.path && tab.isDirty,
            );
            return FileTreeTile(
              key: ValueKey(item.path),
              item: item,
              depth: item.depth,
              isSelected: controller.isSelected(item),
              isExpanded: controller.isExpanded(item),
              isCut: controller.isCut(item.path),
              isEditing: controller.isEditing(item.path),
              highlightQuery:
                  controller.searchMode == ExplorerSearchMode.highlight &&
                      controller.isSearchMatch(item.path)
                  ? controller.searchQuery
                  : null,
              gitStatus: controller.gitStatusFor(
                item.path,
                isDirectory: item.isDirectory,
              ),
              trailing: fileDiagnostics.isNotEmpty
                  ? Tooltip(
                      message: '${fileDiagnostics.length} problem(s)',
                      child: Text(
                        '${fileDiagnostics.length}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                        ),
                      ),
                    )
                  : dirty
                  ? const Tooltip(
                      message: 'Modified',
                      child: Text(
                        'M',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      ),
                    )
                  : null,
              onTap: () async {
                _focusNode.requestFocus();
                if (HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed) {
                  controller.multiSelect(item);
                } else {
                  controller.select(item);
                }
                if (item.isDirectory) {
                  await _run(context, () => controller.toggleExpand(item));
                } else {
                  await _openFile(context, editor, item, isPreview: true);
                }
              },
              onDoubleTap: item.isDirectory
                  ? null
                  : () => _openFile(context, editor, item, isPreview: false),
              onToggleExpand: () =>
                  _run(context, () => controller.toggleExpand(item)),
              onRenameSubmit: (name) =>
                  _rename(context, controller, editor, item, name),
              onRenameCancelled: controller.cancelEdit,
              onSecondaryTapAt: (position) =>
                  _showContextMenu(context, controller, editor, item, position),
              canAcceptDrop: (source) => controller.canMoveTo(source, item),
              onDragEnter: (source) {
                _hoverTimers[item.path]?.cancel();
                if (!controller.isExpanded(item)) {
                  _hoverTimers[item.path] = Timer(
                    const Duration(milliseconds: 800),
                    () => _run(context, () => controller.toggleExpand(item)),
                  );
                }
              },
              onDragLeave: () => _hoverTimers.remove(item.path)?.cancel(),
              onDragAcceptItem: (source) => _transfer(
                context,
                controller,
                editor,
                [source.path],
                item.path,
                copy:
                    HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed,
              ),
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(
    BuildContext context,
    KeyEvent event,
    FileExplorerController controller,
    EditorDocumentsController editor,
    List<FileTreeItem> items,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final selected = controller.selectedPath == null
        ? null
        : controller.findItem(controller.selectedPath!);
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (key == LogicalKeyboardKey.f2 && selected != null) {
      controller.startRename(selected.path);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete && selected != null) {
      _delete(context, controller, editor, controller.selectedPaths);
      return KeyEventResult.handled;
    }
    if (control &&
        key == LogicalKeyboardKey.keyC &&
        HardwareKeyboard.instance.isShiftPressed &&
        selected != null) {
      Clipboard.setData(ClipboardData(text: selected.relativePath));
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isAltPressed &&
        HardwareKeyboard.instance.isShiftPressed &&
        key == LogicalKeyboardKey.keyC &&
        selected != null) {
      Clipboard.setData(ClipboardData(text: selected.path));
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyC && selected != null) {
      controller.copyToClipboard(controller.selectedPaths);
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyX && selected != null) {
      controller.cut(controller.selectedPaths);
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyV && selected != null) {
      final target = selected.isDirectory
          ? selected.path
          : selected.parent?.path;
      if (target != null) {
        _transfer(
          context,
          controller,
          editor,
          controller.selectedPaths,
          target,
          useClipboard: true,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && selected != null) {
      if (selected.isDirectory) {
        _run(context, () => controller.toggleExpand(selected));
      } else {
        _openFile(context, editor, selected, isPreview: false);
      }
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp) &&
        items.isNotEmpty) {
      final currentIndex = items.indexWhere(
        (item) => item.path == selected?.path,
      );
      final nextIndex = key == LogicalKeyboardKey.arrowDown
          ? (currentIndex + 1).clamp(0, items.length - 1)
          : (currentIndex <= 0 ? 0 : currentIndex - 1);
      controller.select(items[nextIndex]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        selected != null &&
        selected.isDirectory) {
      if (!controller.isExpanded(selected)) {
        _run(context, () => controller.toggleExpand(selected));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft &&
        selected != null &&
        selected.isDirectory &&
        controller.isExpanded(selected)) {
      controller.collapse(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home && items.isNotEmpty) {
      controller.select(items.first);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end && items.isNotEmpty) {
      controller.select(items.last);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openFile(
    BuildContext context,
    EditorDocumentsController editor,
    FileTreeItem item, {
    required bool isPreview,
  }  ) async {
    try {
      await _fileOpener.open(
        editor: editor,
        path: item.path,
        isPreview: isPreview,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Unable to open ${item.name}: $error');
    }
  }

  Future<void> _create(
    BuildContext context,
    FileExplorerController controller,
    String name,
  ) async {
    final parent = controller.creatingInPath;
    if (parent == null) return;
    try {
      if (controller.creatingIsDirectory) {
        await controller.createDirectory(parent, name);
      } else {
        await controller.createFile(parent, name);
      }
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Unable to create "$name": $error');
      controller.cancelEdit();
    }
  }

  Future<void> _rename(
    BuildContext context,
    FileExplorerController controller,
    EditorDocumentsController editor,
    FileTreeItem item,
    String name,
  ) async {
    final diagnostics = DiagnosticsScope.of(context);
    try {
      final newPath = _join(_dirname(item.path), name);
      await controller.rename(item.path, name);
      editor.updatePaths(item.path, newPath);
      diagnostics.clearForUri(item.path, recursive: true);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Unable to rename "${item.name}": $error');
    }
  }

  Future<void> _delete(
    BuildContext context,
    FileExplorerController controller,
    EditorDocumentsController editor,
    List<String> paths,
  ) async {
    if (paths.isEmpty) return;
    final confirmed = await DeleteConfirmDialog.show(
      context,
      paths.map(_basename).toList(),
    );
    if (!confirmed || !context.mounted) return;
    final diagnostics = DiagnosticsScope.of(context);
    try {
      await controller.delete(paths);
      for (final path in paths) {
        diagnostics.clearForUri(path, recursive: true);
      }
      editor.closePaths(paths);
    } catch (error) {
      for (final path in paths) {
        if (!await controller.exists(path)) {
          diagnostics.clearForUri(path, recursive: true);
          editor.closePaths([path]);
        }
      }
      if (!context.mounted) return;
      _showError(context, 'Unable to delete selected items: $error');
    }
  }

  Future<void> _transfer(
    BuildContext context,
    FileExplorerController controller,
    EditorDocumentsController editor,
    List<String> paths,
    String target, {
    bool copy = false,
    bool useClipboard = false,
  }) async {
    final sources = useClipboard
        ? List<String>.from(controller.clipboardPaths)
        : paths;
    final isCopy = useClipboard ? !controller.clipboardIsCut : copy;
    for (final source in sources) {
      final name = _basename(source);
      final destination = _join(target, name);
      if (source == destination) continue;
      var replace = false;
      if (await controller.exists(destination)) {
        if (!context.mounted) return;
        final choice = await MoveConflictDialog.show(
          context,
          sourceName: name,
          targetDirectory: target,
        );
        if (choice == MoveConflictChoice.cancel) return;
        if (choice == MoveConflictChoice.skip) continue;
        replace = choice == MoveConflictChoice.replace;
      }
      try {
        if (replace) {
          await controller.delete([destination]);
          editor.closePaths([destination]);
        }
        if (isCopy) {
          await controller.copy([source], target);
        } else {
          await controller.move([source], target);
          editor.updatePaths(source, destination);
        }
      } catch (error) {
        if (!context.mounted) return;
        _showError(context, 'Unable to transfer "$name": $error');
        return;
      }
    }
  }

  Future<void> _showContextMenu(
    BuildContext context,
    FileExplorerController controller,
    EditorDocumentsController editor,
    FileTreeItem item,
    Offset position,
  ) async {
    final size = MediaQuery.sizeOf(context);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        size.width - position.dx,
        size.height - position.dy,
      ),
      items: [
        if (item.isDirectory) ...[
          const PopupMenuItem(value: 'newFile', child: Text('New File')),
          const PopupMenuItem(value: 'newFolder', child: Text('New Folder')),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(value: 'cut', child: Text('Cut')),
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'copyPath', child: Text('Copy Path')),
        const PopupMenuItem(
          value: 'copyRelative',
          child: Text('Copy Relative Path'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
        const PopupMenuDivider(),
        if (item.isDirectory)
          const PopupMenuItem(
            value: 'reveal',
            child: Text('Reveal in File Manager'),
          ),
        const PopupMenuItem(value: 'terminal', child: Text('Open in Terminal')),
      ],
    );
    if (action == null || !context.mounted) return;
    final targetDirectory = item.isDirectory ? item.path : item.parent?.path;
    switch (action) {
      case 'newFile':
        if (targetDirectory != null) {
          controller.startCreate(targetDirectory);
        }
        break;
      case 'newFolder':
        if (targetDirectory != null) {
          controller.startCreate(targetDirectory, isDirectory: true);
        }
        break;
      case 'cut':
        controller.cut(
          controller.selectedPaths.contains(item.path)
              ? controller.selectedPaths
              : [item.path],
        );
        break;
      case 'copy':
        controller.copyToClipboard(
          controller.selectedPaths.contains(item.path)
              ? controller.selectedPaths
              : [item.path],
        );
        break;
      case 'paste':
        if (targetDirectory != null) {
          _transfer(
            context,
            controller,
            editor,
            controller.selectedPaths,
            targetDirectory,
            useClipboard: true,
          );
        }
        break;
      case 'copyPath':
        await Clipboard.setData(ClipboardData(text: item.path));
        break;
      case 'copyRelative':
        await Clipboard.setData(ClipboardData(text: item.relativePath));
        break;
      case 'rename':
        controller.startRename(item.path);
        break;
      case 'delete':
        _delete(context, controller, editor, [item.path]);
        break;
      case 'reveal':
        await _revealInFileManager(context, item.path);
        break;
      case 'terminal':
        await _openTerminal(context, targetDirectory);
        break;
    }
  }

  Future<void> _revealInFileManager(BuildContext context, String path) async {
    final directory = Directory(path).existsSync() ? path : _dirname(path);
    try {
      if (Platform.isLinux) {
        await Process.start('xdg-open', [
          directory,
        ], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [
          directory,
        ], mode: ProcessStartMode.detached);
      } else if (Platform.isWindows) {
        await Process.start('explorer', [
          directory,
        ], mode: ProcessStartMode.detached);
      } else {
        throw UnsupportedError(
          'File manager reveal is not supported on this platform',
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Unable to open file manager: $error');
    }
  }

  Future<void> _openTerminal(BuildContext context, String? directory) async {
    if (directory == null) return;
    try {
      final executable = Platform.isLinux
          ? 'x-terminal-emulator'
          : Platform.isMacOS
          ? 'open'
          : Platform.isWindows
          ? 'cmd'
          : '';
      if (executable.isEmpty) {
        throw UnsupportedError('Terminal is not supported on this platform');
      }
      final args = Platform.isMacOS
          ? ['-a', 'Terminal', directory]
          : <String>[];
      await Process.start(
        executable,
        args,
        workingDirectory: directory,
        mode: ProcessStartMode.detached,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Unable to open terminal: $error');
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Explorer operation failed: $error');
    }
  }

  void _revealSelection(
    FileExplorerController controller,
    List<_TreeRow> rows,
  ) {
    final selected = controller.selectedPath;
    if (selected == null || _isRevealing || !_scrollController.hasClients) {
      return;
    }
    final index = rows.indexWhere((row) => row.item?.path == selected);
    if (index < 0) return;
    _isRevealing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final position = index * 22.0;
        final viewportStart = _scrollController.offset;
        final viewportEnd =
            viewportStart + _scrollController.position.viewportDimension;
        if (position < viewportStart || position + 22 > viewportEnd) {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      }
      _isRevealing = false;
    });
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  String _dirname(String path) {
    final index = path.lastIndexOf(Platform.pathSeparator);
    return index <= 0 ? Platform.pathSeparator : path.substring(0, index);
  }

  String _join(String directory, String name) =>
      directory.endsWith(Platform.pathSeparator)
      ? '$directory$name'
      : '$directory${Platform.pathSeparator}$name';
}

class _TreeRow {
  final FileTreeItem? item;
  final int depth;
  final bool isCreate;

  const _TreeRow._(this.item, this.depth, this.isCreate);

  factory _TreeRow.item(FileTreeItem item) =>
      _TreeRow._(item, item.depth, false);

  factory _TreeRow.create(int depth) => _TreeRow._(null, depth, true);
}
