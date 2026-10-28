import 'package:flutter/material.dart';
import '../../../../core/theme/editor_theme.dart';
import '../../../../core/terminal/services/terminal_config_service.dart';
import '../../../../core/terminal/services/terminal_service.dart';
import 'terminal_instance_view.dart';
import 'terminal_tab_bar.dart';

class TerminalTabbedView extends StatefulWidget {
  final TerminalService terminalService;

  const TerminalTabbedView({required this.terminalService, super.key});

  @override
  State<TerminalTabbedView> createState() => _TerminalTabbedViewState();
}

class _TerminalTabbedViewState extends State<TerminalTabbedView> {
  late final TerminalConfigService _config = TerminalConfigService();
  bool _creatingInitialTerminal = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureTerminal();
  }

  void _ensureTerminal() {
    if (_creatingInitialTerminal ||
        widget.terminalService.instances.isNotEmpty) {
      return;
    }
    _creatingInitialTerminal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.terminalService.instances.isNotEmpty) return;
      try {
        await widget.terminalService.createTerminal();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start terminal: $error')),
          );
        }
      } finally {
        _creatingInitialTerminal = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final instance = widget.terminalService.activeInstance;
    return Column(
      children: [
        TerminalTabBar(terminalService: widget.terminalService, theme: theme),
        Expanded(
          child: instance == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 40,
                        color: theme.panelTitleInactive,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active terminal',
                        style: TextStyle(color: theme.panelTitleInactive),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await widget.terminalService.createTerminal();
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not start terminal: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Terminal'),
                      ),
                    ],
                  ),
                )
              : TerminalInstanceView(
                  key: ValueKey(instance.state.id),
                  instance: instance,
                  terminalService: widget.terminalService,
                  config: _config,
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _config.dispose();
    super.dispose();
  }
}
