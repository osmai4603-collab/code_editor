import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/file_system/controllers/file_explorer_controller.dart';
import '../../../core/file_system/models/sort_config.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../layout/controllers/editor_controller.dart';
import 'explorer_tree.dart';
import 'widgets/open_editors_list.dart';
import 'widgets/section_header.dart';

class ExplorerView extends StatefulWidget {
  const ExplorerView({super.key});

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<ExplorerView> {
  bool _openEditorsExpanded = true;
  bool _workspaceExpanded = true;
  EditorDocumentsController? _documentsController;
  FileExplorerController? _explorerController;
  String? _lastActiveTabId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final docs = EditorDocumentsScope.of(context);
    if (_documentsController != docs) {
      _documentsController?.removeListener(_onActiveDocumentChanged);
      _documentsController = docs;
      _lastActiveTabId = null;
      docs.addListener(_onActiveDocumentChanged);
    }

    final explorer = FileExplorerScope.of(context);
    if (_explorerController != explorer) {
      _explorerController = explorer;
      if (explorer.root == null) {
        unawaited(_openWorkspace(Directory.current.path));
      }
    }
    if (_explorerController?.workspacePath != null) {
      _onActiveDocumentChanged();
    }
  }

  @override
  void dispose() {
    _documentsController?.removeListener(_onActiveDocumentChanged);
    super.dispose();
  }

  void _onActiveDocumentChanged() {
    final tab = _documentsController?.activeTab;
    final explorer = _explorerController;
    if (tab?.id == _lastActiveTabId) return;
    _lastActiveTabId = tab?.id;
    if (tab == null || explorer?.workspacePath == null) return;
    unawaited(
      explorer!.revealAndSelect(tab.path).catchError((Object error) {
        if (mounted) _showError('Unable to reveal file: $error');
      }),
    );
  }

  Future<void> _openWorkspace(String path) async {
    try {
      await _explorerController?.openWorkspace(path);
      _lastActiveTabId = null;
      _onActiveDocumentChanged();
    } catch (error) {
      if (mounted) _showError('Unable to open workspace: $error');
    }
  }

  Future<void> _chooseWorkspace() async {
    final pathController = TextEditingController(
      text: _explorerController?.workspacePath ?? Directory.current.path,
    );
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Folder'),
        content: TextField(
          controller: pathController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder path'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, pathController.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    pathController.dispose();
    if (path != null && path.trim().isNotEmpty) {
      await _openWorkspace(path.trim());
    }
  }

  Future<void> _createAtRoot({required bool directory}) async {
    final root = _explorerController?.root;
    if (root == null) return;
    _explorerController!.startCreate(root.path, isDirectory: directory);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) _showError('Explorer operation failed: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final explorer = FileExplorerScope.of(context);
    final documents = EditorDocumentsScope.of(context);
    final root = explorer.root;
    final workspaceName = root?.name.isNotEmpty == true
        ? root!.name
        : 'NO FOLDER OPEN';

    return Container(
      color: theme.sideBarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.sideBarBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'EXPLORER',
                    style: TextStyle(
                      color: theme.sideBarTitleForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Open Folder',
                  child: IconButton(
                    onPressed: _chooseWorkspace,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    color: theme.sideBarTitleForeground,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Open Editors',
            isExpanded: _openEditorsExpanded,
            onToggle: () =>
                setState(() => _openEditorsExpanded = !_openEditorsExpanded),
          ),
          if (_openEditorsExpanded) OpenEditorsList(controller: documents),
          const SizedBox(height: 4),
          if (explorer.error != null)
            MaterialBanner(
              content: Text(
                explorer.error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TextButton(
                  onPressed: explorer.clearError,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          SectionHeader(
            title: workspaceName,
            isExpanded: _workspaceExpanded,
            onToggle: () =>
                setState(() => _workspaceExpanded = !_workspaceExpanded),
            actions: [
              HeaderAction(
                icon: Icons.note_add_outlined,
                tooltip: 'New File',
                onPressed: () => _createAtRoot(directory: false),
              ),
              HeaderAction(
                icon: Icons.create_new_folder_outlined,
                tooltip: 'New Folder',
                onPressed: () => _createAtRoot(directory: true),
              ),
              HeaderAction(
                icon: Icons.refresh,
                tooltip: 'Refresh Explorer',
                onPressed: () => _run(() => explorer.refresh()),
              ),
              HeaderAction(
                icon: Icons.unfold_less,
                tooltip: 'Collapse All',
                onPressed: explorer.collapseAll,
              ),
              HeaderAction(
                icon: Icons.sort_by_alpha,
                tooltip: 'Sort',
                onPressed: () => _showSortMenu(context, explorer),
              ),
            ],
          ),
          if (_workspaceExpanded) ...[
            // ExplorerSearchBar(controller: explorer),
            Expanded(
              child: root == null
                  ? Center(
                      child: explorer.isLoading
                          ? const CircularProgressIndicator()
                          : TextButton.icon(
                              onPressed: _chooseWorkspace,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Open Folder'),
                            ),
                    )
                  : explorer.isLoading && explorer.getVisibleItems().isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : const ExplorerTree(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSortMenu(
    BuildContext context,
    FileExplorerController controller,
  ) async {
    final choice = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 60, 0, 0),
      items: const [
        PopupMenuItem(value: 'name', child: Text('Sort by Name')),
        PopupMenuItem(value: 'type', child: Text('Sort by Type')),
        PopupMenuItem(value: 'modified', child: Text('Sort by Modified Time')),
        PopupMenuItem(value: 'size', child: Text('Sort by Size')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'hidden', child: Text('Toggle Hidden Files')),
        PopupMenuItem(
          value: 'descending',
          child: Text('Toggle Sort Direction'),
        ),
      ],
    );
    if (choice == null) return;
    final current = controller.sortConfig;
    if (choice == 'hidden') {
      controller.setShowHiddenFiles(!controller.showHiddenFiles);
      return;
    }
    if (choice == 'descending') {
      controller.updateSortConfig(
        SortConfig(
          order: current.order,
          direction: current.direction == SortDirection.ascending
              ? SortDirection.descending
              : SortDirection.ascending,
          folderPosition: current.folderPosition,
          caseSensitive: current.caseSensitive,
        ),
      );
      return;
    }
    final order = switch (choice) {
      'type' => SortOrder.type,
      'modified' => SortOrder.modified,
      'size' => SortOrder.size,
      _ => SortOrder.name,
    };
    controller.updateSortConfig(
      SortConfig(
        order: order,
        direction: current.direction,
        folderPosition: current.folderPosition,
        caseSensitive: current.caseSensitive,
      ),
    );
  }
}
