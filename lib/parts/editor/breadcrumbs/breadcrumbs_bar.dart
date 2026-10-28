import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/breadcrumbs/models/breadcrumb_path_entry.dart';
import '../../../core/breadcrumbs/models/breadcrumb_symbol.dart';
import '../../../core/breadcrumbs/services/breadcrumbs_path_service.dart';
import '../../../core/constants/editor_constants.dart';
import '../../../core/file_system/models/file_tree_item.dart';
import '../../../core/file_system/services/file_icon_resolver.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';

class BreadcrumbsBar extends StatelessWidget {
  final String filePath;
  final String? workspacePath;
  final Future<List<FileTreeItem>> Function(String path) listDirectory;
  final Future<void> Function(String path) openFile;
  final List<BreadcrumbSymbol> symbols;
  final List<BreadcrumbSymbol> activeSymbols;
  final bool symbolsLoading;
  final String? symbolsError;
  final ValueChanged<BreadcrumbSymbol> onSelectSymbol;

  const BreadcrumbsBar({
    super.key,
    required this.filePath,
    required this.workspacePath,
    required this.listDirectory,
    required this.openFile,
    required this.symbols,
    required this.activeSymbols,
    required this.symbolsLoading,
    required this.symbolsError,
    required this.onSelectSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final entries = const BreadcrumbsPathService().buildPath(
      filePath: filePath,
      workspacePath: workspacePath,
    );
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.centerLeft,
      height: EditorConstants.breadcrumbsHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.editorBackground,
        border: Border(
          bottom: BorderSide(
            color: theme.tabBorder.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0) _separator(theme),
                _pathItem(
                  context,
                  theme,
                  entries[index],
                  index == entries.length - 1,
                ),
              ],
              for (var index = 0; index < activeSymbols.length; index++) ...[
                _separator(theme),
                _symbolItem(context, theme, activeSymbols[index], index),
              ],
              if (activeSymbols.isEmpty && symbols.isNotEmpty)
                _symbolChooser(context, theme),
              if (symbolsLoading)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.editorForeground.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              if (symbolsError != null)
                Tooltip(
                  message: 'Unable to load document symbols: $symbolsError',
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: theme.statusBarWarningForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _separator(EditorThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Icon(
      Icons.chevron_right,
      size: 14,
      color: theme.editorForeground.withValues(alpha: 0.4),
    ),
  );

  Widget _pathItem(
    BuildContext context,
    EditorThemeData theme,
    BreadcrumbPathEntry entry,
    bool isCurrent,
  ) {
    final icon = entry.isFile
        ? FileIconResolver.resolveFileIcon(entry.label)
        : FileIconResolver.resolveFolderIcon(entry.label);
    return Tooltip(
      message: entry.label,
      child: Semantics(
        button: true,
        label: '${entry.label}, ${entry.kind.name}',
        child: Builder(
          builder: (itemContext) => InkWell(
            key: ValueKey('breadcrumb-${entry.path}'),
            onTap: () => unawaited(_showFileMenu(context, itemContext, entry)),
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon.icon, size: 13, color: icon.color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
                              ? theme.editorForeground
                              : theme.editorForeground.withValues(alpha: 0.65),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _symbolItem(
    BuildContext context,
    EditorThemeData theme,
    BreadcrumbSymbol symbol,
    int index,
  ) {
    final kind = symbol.kind.name;
    return Tooltip(
      message: '${symbol.name} ($kind)',
      child: Semantics(
        button: true,
        label: '${symbol.name}, $kind',
        child: Builder(
          builder: (itemContext) => InkWell(
            key: ValueKey('breadcrumb-symbol-${symbol.name}'),
            onTap: () =>
                unawaited(_showSymbolMenu(context, itemContext, index)),
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _symbolIcon(symbol.kind),
                      size: 13,
                      color: theme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        symbol.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.editorForeground,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _symbolChooser(BuildContext context, EditorThemeData theme) {
    return Builder(
      builder: (itemContext) => Tooltip(
        message: symbolsLoading ? 'Loading symbols' : 'Choose symbol',
        child: IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          constraints: const BoxConstraints(minWidth: 22, minHeight: 20),
          iconSize: 14,
          color: theme.editorForeground.withValues(alpha: 0.7),
          onPressed: () =>
              unawaited(_showSymbolMenu(context, itemContext, null)),
          icon: const Icon(Icons.account_tree_outlined),
        ),
      ),
    );
  }

  Future<void> _showFileMenu(
    BuildContext context,
    BuildContext anchorContext,
    BreadcrumbPathEntry entry,
  ) async {
    await _showDirectoryMenu(
      context,
      anchorContext,
      entry.directoryPath,
      currentPath: filePath,
    );
  }

  Future<void> _showDirectoryMenu(
    BuildContext context,
    BuildContext anchorContext,
    String directoryPath, {
    required String currentPath,
  }) async {
    try {
      final items = await listDirectory(directoryPath);
      if (!context.mounted) return;
      final position = _menuPosition(context, anchorContext);
      if (position == null) return;
      final selected = await showMenu<String>(
        context: context,
        position: position,
        items: [
          PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text(
              _directoryLabel(directoryPath),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final item in items)
            PopupMenuItem<String>(
              key: ValueKey('breadcrumbs-file-${item.path}'),
              value: item.path,
              child: Row(
                children: [
                  Icon(
                    item.isDirectory
                        ? FileIconResolver.resolveFolderIcon(item.name).icon
                        : FileIconResolver.resolveFileIcon(item.name).icon,
                    size: 16,
                    color: item.isDirectory
                        ? FileIconResolver.resolveFolderIcon(item.name).color
                        : FileIconResolver.resolveFileIcon(item.name).color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.path == currentPath)
                    const Icon(Icons.check, size: 15),
                  if (item.isDirectory)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.chevron_right, size: 15),
                    ),
                ],
              ),
            ),
        ],
      );
      if (!context.mounted || selected == null) return;
      FileTreeItem? chosen;
      for (final item in items) {
        if (item.path == selected) {
          chosen = item;
          break;
        }
      }
      if (chosen == null) return;
      if (chosen.isDirectory) {
        await _showDirectoryMenu(
          context,
          anchorContext,
          chosen.path,
          currentPath: currentPath,
        );
      } else {
        await openFile(chosen.path);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to browse files: $error')));
    }
  }

  Future<void> _showSymbolMenu(
    BuildContext context,
    BuildContext anchorContext,
    int? activeIndex,
  ) async {
    final options = activeIndex == null
        ? symbols
        : activeSymbols[activeIndex].children.isNotEmpty
        ? activeSymbols[activeIndex].children
        : activeIndex == 0
        ? symbols
        : activeSymbols[activeIndex - 1].children;
    if (options.isEmpty) return;
    final position = _menuPosition(context, anchorContext);
    if (position == null) return;
    final selected = await showMenu<BreadcrumbSymbol>(
      context: context,
      position: position,
      items: [
        for (final symbol in options)
          PopupMenuItem<BreadcrumbSymbol>(
            value: symbol,
            child: Row(
              children: [
                Icon(_symbolIcon(symbol.kind), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    symbol.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (selected != null && context.mounted) onSelectSymbol(selected);
  }

  RelativeRect? _menuPosition(
    BuildContext context,
    BuildContext anchorContext,
  ) {
    final anchorObject = anchorContext.findRenderObject();
    final fallbackObject = context.findRenderObject();
    final anchor = anchorObject is RenderBox && anchorObject.hasSize
        ? anchorObject
        : fallbackObject;
    if (anchor is! RenderBox || !anchor.hasSize) {
      return RelativeRect.fromLTRB(8, 8, 8, MediaQuery.sizeOf(context).height);
    }
    final topLeft = anchor.localToGlobal(Offset.zero);
    final viewport = MediaQuery.sizeOf(context);
    return RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      (viewport.width - topLeft.dx - anchor.size.width).clamp(
        0,
        viewport.width,
      ),
      (viewport.height - topLeft.dy - anchor.size.height).clamp(
        0,
        viewport.height,
      ),
    );
  }

  String _directoryLabel(String path) {
    final labels = const BreadcrumbsPathService()
        .buildPath(filePath: path, workspacePath: workspacePath)
        .map((entry) => entry.label);
    final label = labels.join(' › ');
    return label.isEmpty ? path : label;
  }

  IconData _symbolIcon(LspSymbolKind kind) => switch (kind) {
    LspSymbolKind.classKind ||
    LspSymbolKind.interfaceKind ||
    LspSymbolKind.struct => Icons.class_outlined,
    LspSymbolKind.method ||
    LspSymbolKind.function ||
    LspSymbolKind.constructor => Icons.functions,
    LspSymbolKind.field ||
    LspSymbolKind.property ||
    LspSymbolKind.variable => Icons.data_object,
    LspSymbolKind.enumKind || LspSymbolKind.enumMember => Icons.label_outline,
    LspSymbolKind.constant => Icons.pin_outlined,
    _ => Icons.code,
  };
}
