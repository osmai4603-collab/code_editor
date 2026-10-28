import 'package:flutter/material.dart';

import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/models/layout_state.dart';
import 'explorer/explorer_view.dart';

class SideBarWidget extends StatelessWidget {
  const SideBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final layout = WorkbenchLayoutScope.of(context).state;
    if (layout.activeActivity != ActivityBarItem.explorer) {
      return Container(
        decoration: BoxDecoration(
          color: theme.sideBarBackground,
          border: Border(
            right: BorderSide(color: theme.sideBarBorder, width: 1),
          ),
        ),
        child: Center(
          child: Text(
            '${layout.activeActivity} View Container',
            style: TextStyle(
              color: theme.sideBarForeground.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return const ExplorerView();
  }
}
