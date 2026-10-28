import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_data.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/editor_controller.dart';
import '../../layout/controllers/layout_controller.dart';

/// شريط العنوان العلوي (TitleBar) المجهز بمركز الأوامر وأزرار التحكم بالتخطيط
class TitleBarWidget extends StatelessWidget {
  const TitleBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final appTheme = AppTheme.maybeOf(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final layoutState = layoutController.state;
    final editorController = EditorDocumentsScope.of(context);
    final activeTab = editorController.activeTab;

    return Container(
      height: EditorConstants.titleBarHeight,
      decoration: BoxDecoration(
        color: theme.titleBarBackground,
        border: Border(
          bottom: BorderSide(color: theme.titleBarBorder, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // لوجو المحرر وقوائم التطبيق الأساسية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                Icon(Icons.code_rounded, size: 18, color: theme.accentColor),
                const SizedBox(width: 8),
                _buildMenuButton('File', theme),
                _buildMenuButton('Edit', theme),
                _buildMenuButton('Selection', theme),
                _buildMenuButton('View', theme),
                _buildMenuButton('Go', theme),
                _buildMenuButton('Terminal', theme),
                _buildMenuButton('Help', theme),
              ],
            ),
          ),

          // مركز الأوامر والبحث في المنتصف (Command Center)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.commandCenterBackground,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: theme.commandCenterBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 14, color: theme.commandCenterForeground),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          activeTab != null
                              ? 'code_editor - ${activeTab.title}'
                              : 'code_editor (Ctrl+Shift+P for commands)',
                          style: TextStyle(
                            color: theme.commandCenterForeground,
                            fontSize: 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // أزرار التحكم بالنوافذ والتخطيط (Layout Controls)
          Row(
            children: [
              if (appTheme != null) _buildThemePicker(context, appTheme),
              _buildIconButton(
                icon: Icons.dock_rounded,
                tooltip: 'Toggle Primary SideBar',
                isActive: layoutState.isSideBarVisible,
                theme: theme,
                onPressed: layoutController.toggleSideBar,
              ),
              _buildIconButton(
                icon: Icons.view_agenda_outlined,
                tooltip: 'Toggle Panel',
                isActive: layoutState.isPanelVisible,
                theme: theme,
                onPressed: layoutController.togglePanel,
              ),
              _buildIconButton(
                icon: Icons.vertical_split_outlined,
                tooltip: 'Toggle Secondary SideBar (AI / Outline)',
                isActive: layoutState.isAuxiliaryBarVisible,
                theme: theme,
                onPressed: layoutController.toggleAuxiliaryBar,
              ),
              _buildIconButton(
                icon: Icons.horizontal_rule_rounded,
                tooltip: layoutState.isStatusBarVisible
                    ? 'Hide Status Bar'
                    : 'Show Status Bar',
                isActive: layoutState.isStatusBarVisible,
                theme: theme,
                onPressed: layoutController.toggleStatusBar,
              ),
              _buildIconButton(
                icon: Icons.fullscreen_rounded,
                tooltip: 'Zen Mode',
                isActive: layoutState.isZenMode,
                theme: theme,
                onPressed: layoutController.toggleZenMode,
              ),
              const SizedBox(width: 12),
              // أزرار إدارة النافذة الأساسية
              _buildWindowActionButton(Icons.remove, 'Minimize', theme, () {}),
              _buildWindowActionButton(Icons.crop_square, 'Maximize', theme, () {}),
              _buildWindowActionButton(Icons.close, 'Close', theme, () {}, isClose: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemePicker(BuildContext context, AppTheme appTheme) {
    return PopupMenuButton<AppThemeData>(
      tooltip: 'Color Theme: ${appTheme.theme.label}',
      initialValue: appTheme.theme,
      onSelected: (theme) => _changeTheme(context, appTheme, theme),
      itemBuilder: (context) => [
        for (final theme in AppThemeData.all)
          PopupMenuItem<AppThemeData>(
            value: theme,
            child: Row(
              children: [
                Icon(
                  theme.id == appTheme.theme.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(theme.label),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.color_lens_outlined,
          size: 17,
          color: appTheme.theme.editorTheme.titleBarForeground,
        ),
      ),
    );
  }

  void _changeTheme(
    BuildContext context,
    AppTheme appTheme,
    AppThemeData theme,
  ) {
    unawaited(() async {
      try {
        await appTheme.onThemeChanged(theme);
      } catch (error, stackTrace) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'theme selection',
              context: ErrorDescription('while saving the selected theme'),
            ),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Unable to save color theme: $error')),
        );
      }
    }());
  }

  Widget _buildMenuButton(String title, EditorThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          title,
          style: TextStyle(
            color: theme.titleBarForeground,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required EditorThemeData theme,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? theme.accentColor : theme.titleBarForeground.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowActionButton(
    IconData icon,
    String tooltip,
    EditorThemeData theme,
    VoidCallback onPressed, {
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? Colors.red.withValues(alpha: 0.8) : Colors.white10,
        child: Container(
          width: 32,
          height: EditorConstants.titleBarHeight,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 13,
            color: theme.titleBarForeground,
          ),
        ),
      ),
    );
  }
}
