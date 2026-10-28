import 'package:flutter/material.dart';

import '../../../../core/file_system/models/file_tree_item.dart';
import '../../../../core/file_system/services/file_icon_resolver.dart';
import '../../../../core/theme/editor_theme.dart';
import 'inline_rename_field.dart';

class FileTreeTile extends StatelessWidget {
  final FileTreeItem item;
  final int depth;
  final bool isSelected;
  final bool isExpanded;
  final bool isCut;
  final bool isEditing;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleExpand;
  final ValueChanged<String>? onRenameSubmit;
  final VoidCallback? onRenameCancelled;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<Offset>? onSecondaryTapAt;
  final bool isDropTarget;
  final bool Function(FileTreeItem)? canAcceptDrop;
  final ValueChanged<FileTreeItem>? onDragAcceptItem;
  final ValueChanged<FileTreeItem>? onDragEnter;
  final VoidCallback? onDragLeave;
  final Widget? trailing;

  const FileTreeTile({
    super.key,
    required this.item,
    required this.depth,
    this.isSelected = false,
    this.isExpanded = false,
    this.isCut = false,
    this.isEditing = false,
    this.onTap,
    this.onDoubleTap,
    this.onToggleExpand,
    this.onRenameSubmit,
    this.onRenameCancelled,
    this.onSecondaryTap,
    this.onSecondaryTapAt,
    this.isDropTarget = false,
    this.canAcceptDrop,
    this.onDragAcceptItem,
    this.onDragEnter,
    this.onDragLeave,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final resolved = item.isDirectory
        ? FileIconResolver.resolveFolderIcon(item.name, isExpanded: isExpanded)
        : FileIconResolver.resolveFileIcon(item.name);
    final content = GestureDetector(
      onSecondaryTapUp: (details) {
        onSecondaryTap?.call();
        onSecondaryTapAt?.call(details.globalPosition);
      },
      child: InkWell(
        onTap: isEditing ? null : onTap,
        onDoubleTap: isEditing ? null : onDoubleTap,
        child: Container(
          height: 22,
          color: isDropTarget
              ? theme.accentColor.withValues(alpha: 0.3)
              : isSelected
              ? theme.editorSelection
              : Colors.transparent,
          padding: const EdgeInsets.only(left: 4, right: 6),
          child: Row(
            children: [
              for (var level = 0; level < depth; level++)
                SizedBox(
                  width: 16,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 1,
                      height: 22,
                      color: theme.sideBarForeground.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              SizedBox(
                width: 16,
                child: item.isDirectory
                    ? InkWell(
                        onTap: onToggleExpand,
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: theme.sideBarForeground.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 2),
              Icon(resolved.icon, size: 16, color: resolved.color),
              const SizedBox(width: 6),
              Expanded(
                child: isEditing
                    ? InlineRenameField(
                        initialName: item.name,
                        onSubmit: onRenameSubmit ?? (_) {},
                        onCancel: onRenameCancelled ?? () {},
                      )
                    : Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.sideBarForeground,
                          fontSize: 12.5,
                          fontStyle: isCut
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
              ),
              if (item.isSymbolicLink)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(
                    Icons.link,
                    size: 12,
                    color: theme.sideBarForeground.withValues(alpha: 0.65),
                  ),
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );

    return DragTarget<FileTreeItem>(
      onWillAcceptWithDetails: (details) =>
          item.isDirectory &&
          (canAcceptDrop?.call(details.data) ?? false) &&
          _startHover(details.data),
      onLeave: (_) => onDragLeave?.call(),
      onAcceptWithDetails: (details) => onDragAcceptItem?.call(details.data),
      builder: (context, candidateData, rejectedData) {
        final target = candidateData.isNotEmpty || isDropTarget;
        return Draggable<FileTreeItem>(
          data: item,
          maxSimultaneousDrags: item.isRoot ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(6),
              color: theme.sideBarBackground,
              child: Text(
                item.name,
                style: TextStyle(color: theme.sideBarForeground),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.5, child: content),
          child: target
              ? FileTreeTile._dropHighlighted(child: content, theme: theme)
              : content,
        );
      },
    );
  }

  bool _startHover(FileTreeItem dragged) {
    onDragEnter?.call(dragged);
    return true;
  }

  static Widget _dropHighlighted({
    required Widget child,
    required EditorThemeData theme,
  }) =>
      ColoredBox(color: theme.accentColor.withValues(alpha: 0.2), child: child);
}
