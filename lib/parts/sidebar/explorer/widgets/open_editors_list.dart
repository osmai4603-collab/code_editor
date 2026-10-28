import 'package:flutter/material.dart';

import '../../../../core/file_system/services/file_icon_resolver.dart';
import '../../../../core/theme/editor_theme.dart';
import '../../../../layout/controllers/editor_controller.dart';

class OpenEditorsList extends StatelessWidget {
  final EditorDocumentsController controller;

  const OpenEditorsList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    return Column(
      children: [
        for (final tab in controller.tabs)
          InkWell(
            onTap: () => controller.selectTab(tab.id),
            child: SizedBox(
              height: 24,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 8),
                child: Row(
                  children: [
                    Icon(
                      FileIconResolver.resolveFileIcon(tab.title).icon,
                      size: 14,
                      color: FileIconResolver.resolveFileIcon(tab.title).color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tab.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: controller.activeTab?.id == tab.id
                              ? Colors.white
                              : theme.sideBarForeground,
                          fontSize: 12,
                          fontStyle: tab.isPreview
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (tab.isDirty)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => controller.closeTab(tab.id),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: theme.sideBarForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
