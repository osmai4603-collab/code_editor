import 'package:flutter/material.dart';
import '../../../../core/theme/editor_theme.dart';
import '../../../../core/terminal/services/terminal_service.dart';

class TerminalTabBar extends StatelessWidget {
  final TerminalService terminalService;
  final EditorThemeData theme;

  const TerminalTabBar({
    required this.terminalService,
    required this.theme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.panelBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: terminalService.instances.length,
              itemBuilder: (context, index) {
                final instance = terminalService.instances[index];
                final active = index == terminalService.activeIndex;
                return GestureDetector(
                  onTap: () => terminalService.setActiveTerminal(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 1,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? theme.tabActiveBackground
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 12,
                          color: active
                              ? theme.accentColor
                              : theme.panelTitleInactive,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            instance.state.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: active
                                  ? theme.panelTitleActive
                                  : theme.panelTitleInactive,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => terminalService.closeTerminal(index),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: theme.panelTitleInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _iconButton(
            context,
            Icons.add,
            'New Terminal',
            () => _createTerminal(context),
          ),
          _iconButton(
            context,
            Icons.delete_outline,
            'Kill Terminal',
            () => terminalService.closeTerminal(terminalService.activeIndex),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 15, color: theme.panelForeground),
      ),
    ),
  );

  Future<void> _createTerminal(BuildContext context) async {
    try {
      await terminalService.createTerminal();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start terminal: $error')),
        );
      }
    }
  }
}
