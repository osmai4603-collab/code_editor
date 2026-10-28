import 'package:flutter/material.dart';
import '../../../core/theme/editor_theme.dart';

/// ويدجت عرض روابط وأزرار CodeLens التفاعلية ("Run | Debug") فوق السطور البرمجية
class CodeLensWidget extends StatelessWidget {
  final VoidCallback onRun;
  final VoidCallback? onDebug;

  const CodeLensWidget({
    super.key,
    required this.onRun,
    this.onDebug,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLensButton('Run', onRun, theme),
          Text(
            ' | ',
            style: TextStyle(
              color: theme.editorForeground.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
          _buildLensButton('Debug', onDebug ?? onRun, theme),
        ],
      ),
    );
  }

  Widget _buildLensButton(String title, VoidCallback onTap, EditorThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          title,
          style: TextStyle(
            color: theme.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
