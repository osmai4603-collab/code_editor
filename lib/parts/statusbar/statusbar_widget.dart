import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/editor_constants.dart';
import '../../core/statusbar/models/status_bar_alignment.dart';
import '../../core/statusbar/models/status_bar_entry.dart';
import '../../core/statusbar/status_bar_scope.dart';
import '../../core/statusbar/status_bar_service.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/layout_controller.dart';
import 'statusbar_item_widget.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final statusBar = StatusBarScope.of(context);
    final layout = WorkbenchLayoutScope.of(context);

    return SizedBox(
      height: EditorConstants.statusBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.statusBarBackground,
          border: Border(top: BorderSide(color: theme.sideBarBorder, width: 1)),
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1,
          child: ListenableBuilder(
            listenable: statusBar,
            builder: (context, _) {
              final entries = statusBar.visibleEntries;
              final leftEntries = entries
                  .where((entry) => entry.alignment == StatusBarAlignment.left)
                  .toList();
              final rightEntries = entries
                  .where((entry) => entry.alignment == StatusBarAlignment.right)
                  .toList();

              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildEntryGroup(context, statusBar, leftEntries),
                  ),
                  Expanded(
                    child: _buildEntryGroup(
                      context,
                      statusBar,
                      rightEntries,
                      reverse: true,
                      mainAxisAlignment: MainAxisAlignment.end,
                    ),
                  ),
                  _buildManagementMenu(context, statusBar, layout),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEntryGroup(
    BuildContext context,
    StatusBarService service,
    List<StatusBarEntry> entries, {
    bool reverse = false,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: reverse,
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries)
            StatusBarItemWidget(
              key: ValueKey(entry.id),
              entry: entry,
              onHide: () => _changeVisibility(context, service, entry, false),
            ),
        ],
      ),
    );
  }

  Widget _buildManagementMenu(
    BuildContext context,
    StatusBarService service,
    WorkbenchLayoutController layout,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Manage Status Bar',
      padding: EdgeInsets.zero,
      iconSize: 16,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 22),
      itemBuilder: (context) => [
        for (final entry in service.entries)
          PopupMenuItem<String>(
            onTap: () => unawaited(
              _changeVisibility(
                  context,
                  service,
                  entry,
                  !service.isEntryVisible(entry.id),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  service.isEntryVisible(entry.id)
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(entry.name)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          onTap: layout.toggleStatusBar,
          child: Text('Hide Status Bar'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Icon(
          Icons.more_horiz,
          size: 16,
          color: EditorTheme.of(context).statusBarForeground,
        ),
      ),
    );
  }

  Future<void> _changeVisibility(
    BuildContext context,
    StatusBarService service,
    StatusBarEntry entry,
    bool visible,
  ) async {
    try {
      await service.setEntryVisible(entry.id, visible);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save this status bar setting; it will not persist after restart: $error',
            ),
          ),
        );
      }
    }
  }
}
