import 'package:flutter/material.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/controllers/editor_controller.dart';
import '../../layout/models/layout_state.dart';

/// شريط الأنشطة الجانبي (ActivityBar)
class ActivityBarWidget extends StatelessWidget {
  const ActivityBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final editorController = EditorDocumentsScope.of(context);
    final layoutState = layoutController.state;

    return Container(
      width: EditorConstants.activityBarWidth,
      decoration: BoxDecoration(
        color: theme.activityBarBackground,
        border: Border(
          right: BorderSide(color: theme.sideBarBorder, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // أيقونات التنقل العلوية
          _buildItem(
            icon: Icons.copy_rounded,
            tooltip: 'Explorer (Ctrl+Shift+E)',
            isSelected:
                layoutState.isSideBarVisible &&
                layoutState.activeActivity == ActivityBarItem.explorer,
            theme: theme,
            onTap: () =>
                layoutController.selectActivity(ActivityBarItem.explorer),
          ),
          _buildItem(
            icon: Icons.search_rounded,
            tooltip: 'Search (Ctrl+Shift+F)',
            isSelected:
                layoutState.isSideBarVisible &&
                layoutState.activeActivity == ActivityBarItem.search,
            theme: theme,
            onTap: () =>
                layoutController.selectActivity(ActivityBarItem.search),
          ),
          _buildItem(
            icon: Icons.alt_route_rounded,
            tooltip: 'Source Control (Ctrl+Shift+G)',
            isSelected:
                layoutState.isSideBarVisible &&
                layoutState.activeActivity == ActivityBarItem.sourceControl,
            theme: theme,
            onTap: () =>
                layoutController.selectActivity(ActivityBarItem.sourceControl),
          ),
          _buildItem(
            icon: Icons.play_arrow_outlined,
            tooltip: 'Run and Debug (Ctrl+Shift+D)',
            isSelected:
                layoutState.isSideBarVisible &&
                layoutState.activeActivity == ActivityBarItem.runDebug,
            theme: theme,
            onTap: () =>
                layoutController.selectActivity(ActivityBarItem.runDebug),
          ),
          _buildItem(
            icon: Icons.grid_view_rounded,
            tooltip: 'Extensions (Ctrl+Shift+X)',
            isSelected:
                layoutState.isSideBarVisible &&
                layoutState.activeActivity == ActivityBarItem.extensions,
            theme: theme,
            onTap: () =>
                layoutController.selectActivity(ActivityBarItem.extensions),
          ),

          const Spacer(),

          // أيقونات الحساب والإعدادات السفلية
          _buildItem(
            icon: Icons.account_circle_outlined,
            tooltip: 'Accounts',
            isSelected: false,
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            icon: Icons.settings_outlined,
            tooltip: 'Manage Settings (Ctrl+,)',
            isSelected: false,
            theme: theme,
            onTap: editorController.openSettingsTab,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required EditorThemeData theme,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: EditorConstants.activityBarWidth,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // خط المؤشر النشط في الجانب الأيسر
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  width: 2.5,
                  child: Container(color: theme.activityBarActiveBorder),
                ),
              Icon(
                icon,
                size: EditorConstants.activityBarIconSize,
                color: isSelected ? Colors.white : theme.activityBarForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
