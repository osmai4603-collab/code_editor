import 'package:flutter/material.dart';

import '../../../../core/theme/editor_theme.dart';

class HeaderAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
}

class SectionHeader extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<HeaderAction> actions;

  const SectionHeader({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                      color: theme.sideBarTitleForeground,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.sideBarTitleForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final action in actions)
            Tooltip(
              message: action.tooltip,
              child: InkWell(
                onTap: action.onPressed,
                child: SizedBox(
                  width: 25,
                  height: 24,
                  child: Icon(
                    action.icon,
                    size: 14,
                    color: theme.sideBarTitleForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
