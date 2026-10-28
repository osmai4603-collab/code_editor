import 'package:flutter/material.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/editor_controller.dart';
import '../../layout/controllers/layout_controller.dart';

/// شريط الحالة السفلي (StatusBar)
class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final editorController = EditorDocumentsScope.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final activeTab = editorController.activeTab;

    return Container(
      height: EditorConstants.statusBarHeight,
      decoration: BoxDecoration(
        color: theme.statusBarBackground,
        border: Border(
          top: BorderSide(color: theme.sideBarBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // الجانب الأيسر: معلومات المشروع وإدارة الإصدارات
          _buildItem(
            icon: Icons.source,
            label: 'main*',
            tooltip: 'Git Branch: main',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            icon: Icons.sync,
            label: '',
            tooltip: 'Synchronize Changes',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            icon: Icons.error_outline,
            label: '0',
            tooltip: 'No Errors',
            theme: theme,
            onTap: layoutController.togglePanel,
          ),
          _buildItem(
            icon: Icons.warning_amber_rounded,
            label: '0',
            tooltip: 'No Warnings',
            theme: theme,
            onTap: layoutController.togglePanel,
          ),

          const Spacer(),

          // الجانب الأيمن: سياق المحرر والموقع والترميز
          _buildItem(
            label: 'Ln 1, Col 1',
            tooltip: 'Go to Line/Column',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            label: 'Spaces: 2',
            tooltip: 'Indentation: Spaces',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            label: 'UTF-8',
            tooltip: 'Select Encoding',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            label: 'LF',
            tooltip: 'End of Line Sequence',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            icon: Icons.auto_awesome,
            label: activeTab != null ? activeTab.languageId.toUpperCase() : 'PLAIN TEXT',
            tooltip: 'Select Language Mode',
            theme: theme,
            onTap: () {},
          ),
          _buildItem(
            icon: Icons.notifications_none_outlined,
            label: '',
            tooltip: 'No Notifications',
            theme: theme,
            onTap: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildItem({
    IconData? icon,
    required String label,
    required String tooltip,
    required EditorThemeData theme,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: EditorConstants.statusBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: theme.statusBarForeground),
                if (label.isNotEmpty) const SizedBox(width: 4),
              ],
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(
                    color: theme.statusBarForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
