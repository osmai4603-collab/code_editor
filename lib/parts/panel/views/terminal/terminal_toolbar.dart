import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/editor_theme.dart';
import '../../../../core/terminal/services/terminal_service.dart';
import 'terminal_selection.dart';

class TerminalToolbar extends StatelessWidget {
  final TerminalInstance instance;
  final TerminalService terminalService;
  final EditorThemeData theme;
  final TerminalSelection selection;
  final int scrollOffset;

  const TerminalToolbar({
    required this.instance,
    required this.terminalService,
    required this.theme,
    required this.selection,
    required this.scrollOffset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.panelBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.content_copy, 'Copy', () async {
            final text = selection.getSelectedText(
              instance.state.buffer,
              scrollOffset: scrollOffset,
            );
            if (text.isNotEmpty) {
              await Clipboard.setData(ClipboardData(text: text));
            }
          }),
          _button(Icons.content_paste, 'Paste', () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              final text = instance.state.bracketedPasteMode
                  ? '\x1b[200~${data!.text}\x1b[201~'
                  : data!.text!;
              instance.processManager.sendInput(text);
            }
          }),
          _button(Icons.clear_all, 'Clear', () {
            instance.state.buffer.clear();
            instance.state.cursor.moveTo(
              0,
              0,
              maxRows: instance.state.buffer.rows,
              maxCols: instance.state.buffer.cols,
            );
            instance.state.notify();
          }),
          _button(Icons.add, 'New Terminal', () async {
            try {
              await terminalService.createTerminal();
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not start terminal: $error')),
                );
              }
            }
          }),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback onPressed) =>
      Tooltip(
        message: tooltip,
        child: IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 15,
          color: theme.panelForeground,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      );
}
