import 'package:flutter/material.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/models/layout_state.dart';

/// الشريط الجانبي الإضافي / الأيمن (AuxiliaryBar - Secondary SideBar)
class AuxiliaryBarWidget extends StatelessWidget {
  const AuxiliaryBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final layoutState = layoutController.state;

    return Container(
      decoration: BoxDecoration(
        color: theme.auxiliaryBarBackground,
        border: Border(
          left: BorderSide(color: theme.auxiliaryBarBorder, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // شريط عناوين التبويبات (CHAT / OUTLINE)
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.auxiliaryBarBorder, width: 1.0),
              ),
            ),
            child: Row(
              children: [
                _buildTab(
                  title: 'CHAT',
                  isSelected: layoutState.activeAuxiliaryTab == AuxiliaryBarTab.chat,
                  theme: theme,
                  onTap: () => layoutController.selectAuxiliaryTab(AuxiliaryBarTab.chat),
                ),
                const SizedBox(width: 8),
                _buildTab(
                  title: 'OUTLINE',
                  isSelected: layoutState.activeAuxiliaryTab == AuxiliaryBarTab.outline,
                  theme: theme,
                  onTap: () => layoutController.selectAuxiliaryTab(AuxiliaryBarTab.outline),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Close Secondary SideBar',
                  child: InkWell(
                    onTap: layoutController.toggleAuxiliaryBar,
                    child: Icon(Icons.close, size: 16, color: theme.sideBarForeground),
                  ),
                ),
              ],
            ),
          ),

          // المحتوى
          Expanded(
            child: layoutState.activeAuxiliaryTab == AuxiliaryBarTab.chat
                ? _buildChatContent(theme)
                : _buildOutlineContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required bool isSelected,
    required EditorThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: isSelected
              ? Border(bottom: BorderSide(color: theme.accentColor, width: 2.0))
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.sideBarTitleForeground,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChatContent(EditorThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildMessageBubble(
                'AI Assistant',
                'مرحباً بك! أنا المساعد الذكي لمحرر الأكواد. كيف يمكنني مساعدتك في مشروعك اليوم؟',
                isAi: true,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildMessageBubble(
                'You',
                'اشرح لي كيف تم تنظيم هذا المحرر برمجياً.',
                isAi: false,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildMessageBubble(
                'AI Assistant',
                'المحرر مبني بهيكلية مطابقة لـ VS Code مع تقسيم الواجهة إلى 8 أجزاء رئيسية وفواصل تحجيم مرنة.',
                isAi: true,
                theme: theme,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.auxiliaryBarBorder, width: 1.0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: theme.editorForeground, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Ask AI assistant...',
                    hintStyle: TextStyle(color: theme.sideBarForeground.withValues(alpha: 0.4), fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: theme.auxiliaryBarBorder),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.send_rounded, size: 16, color: theme.accentColor),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutlineContent(EditorThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildOutlineItem('CodeEditorApp', Icons.class_outlined, theme),
        _buildOutlineItem('build(BuildContext)', Icons.functions, theme, depth: 1),
        _buildOutlineItem('WorkbenchScaffold', Icons.class_outlined, theme),
        _buildOutlineItem('build(BuildContext)', Icons.functions, theme, depth: 1),
      ],
    );
  }

  Widget _buildOutlineItem(String label, IconData icon, EditorThemeData theme, {int depth = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.accentColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: theme.sideBarForeground, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String sender, String text, {required bool isAi, required EditorThemeData theme}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAi ? theme.sideBarBackground.withValues(alpha: 0.8) : theme.accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.auxiliaryBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            style: TextStyle(
              color: isAi ? theme.accentColor : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(color: theme.editorForeground, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
