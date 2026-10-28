import 'package:flutter/material.dart';
import '../../../../core/terminal/services/terminal_scope.dart';
import 'terminal_tabbed_view.dart';

class TerminalPanelView extends StatelessWidget {
  const TerminalPanelView({super.key});

  @override
  Widget build(BuildContext context) =>
      TerminalTabbedView(terminalService: TerminalScope.of(context));
}
