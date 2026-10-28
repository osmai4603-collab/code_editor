import 'package:flutter/material.dart';

import '../../core/constants/editor_constants.dart';
import '../../core/statusbar/models/status_bar_entry.dart';
import '../../core/statusbar/models/status_bar_entry_kind.dart';
import '../../core/theme/editor_theme.dart';

class StatusBarItemWidget extends StatefulWidget {
  final StatusBarEntry entry;
  final Future<void> Function()? onHide;

  const StatusBarItemWidget({super.key, required this.entry, this.onHide});

  @override
  State<StatusBarItemWidget> createState() => _StatusBarItemWidgetState();
}

class _StatusBarItemWidgetState extends State<StatusBarItemWidget> {
  bool _showFocusHighlight = false;

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final entry = widget.entry;
    final color = switch (entry.kind) {
      StatusBarEntryKind.standard => theme.statusBarForeground,
      StatusBarEntryKind.warning => theme.statusBarWarningForeground,
      StatusBarEntryKind.error => theme.statusBarErrorForeground,
    };
    final tooltip = entry.tooltip?.isNotEmpty == true
        ? entry.tooltip!
        : entry.name;
    final item = Container(
      height: EditorConstants.statusBarHeight,
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: _showFocusHighlight
            ? Border.all(color: theme.statusBarItemFocus)
            : null,
        color: switch (entry.kind) {
          StatusBarEntryKind.standard => null,
          StatusBarEntryKind.warning => theme.statusBarWarningBackground,
          StatusBarEntryKind.error => theme.statusBarErrorBackground,
        },
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.icon != null) ...[
            Icon(entry.icon, size: 12, color: color),
            if (entry.text.isNotEmpty) const SizedBox(width: 4),
          ],
          if (entry.text.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                entry.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: entry.ariaLabel?.isNotEmpty == true
          ? entry.ariaLabel
          : '${entry.name}: ${entry.text}',
      button: entry.onPressed != null,
      enabled: entry.onPressed != null,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: widget.onHide == null
              ? null
              : (details) => _showContextMenu(context, details.globalPosition),
          onLongPressStart: widget.onHide == null
              ? null
              : (details) => _showContextMenu(context, details.globalPosition),
          child: entry.onPressed == null
              ? item
              : InkWell(
                  onTap: entry.onPressed,
                  onFocusChange: (value) {
                    if (_showFocusHighlight != value) {
                      setState(() => _showFocusHighlight = value);
                    }
                  },
                  hoverColor: theme.statusBarItemHover,
                  focusColor: theme.statusBarItemFocus.withValues(alpha: 0.18),
                  child: item,
                ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'hide', child: Text('Hide this item')),
      ],
    );
    if (selected == 'hide' && context.mounted) {
      await widget.onHide?.call();
    }
  }
}
