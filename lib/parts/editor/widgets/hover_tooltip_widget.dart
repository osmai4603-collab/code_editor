import 'package:flutter/material.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';

/// نافذة التوثيق والمعلومات العائمة (Hover Tooltip Widget)
class HoverTooltipWidget extends StatelessWidget {
  final HoverInfo hoverInfo;
  final Offset position;
  final VoidCallback onDismiss;

  const HoverTooltipWidget({
    super.key,
    required this.hoverInfo,
    required this.position,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);

    return Positioned(
      left: position.dx.clamp(40.0, 600.0),
      top: (position.dy - 60).clamp(20.0, 600.0),
      child: Material(
        elevation: 6,
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.editorBackground,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              hoverInfo.contents,
              style: TextStyle(
                color: theme.editorForeground,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
