import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/output/output_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/controllers/lsp_and_execution_scope.dart';
import '../../layout/models/layout_state.dart';
import 'views/execution_output_view.dart';
import 'views/problems_view.dart';
import 'views/terminal/terminal_panel_view.dart';

class PanelWidget extends StatefulWidget {
  const PanelWidget({super.key});

  @override
  State<PanelWidget> createState() => _PanelWidgetState();
}

class _PanelWidgetState extends State<PanelWidget> {
  final Map<PanelTab, Widget> _panelBodies = {};

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final layoutState = layoutController.state;
    final diagnosticsService = DiagnosticsScope.of(context);
    final executionController = ExecutionScope.of(context);
    final outputService = OutputScope.of(context);

    _panelBodies.putIfAbsent(
      layoutState.activePanelTab,
      () => _buildTabBody(
        layoutState.activePanelTab,
        diagnosticsService,
        executionController,
        outputService,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.panelBackground,
        border: Border(top: BorderSide(color: theme.panelBorder, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.panelBorder.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tab in PanelTab.values)
                          _buildPanelTab(
                            tab: tab,
                            isSelected: layoutState.activePanelTab == tab,
                            theme: theme,
                            diagnosticsService: diagnosticsService,
                            executionController: executionController,
                            onTap: () => layoutController.selectPanelTab(tab),
                          ),
                      ],
                    ),
                  ),
                ),
                _buildActionIcon(
                  context,
                  icon: layoutState.isPanelMaximized
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: layoutState.isPanelMaximized
                      ? 'Restore Panel Size'
                      : 'Maximize Panel Size',
                  theme: theme,
                  onPressed: layoutController.togglePanelMaximized,
                ),
                _buildActionIcon(
                  context,
                  icon: Icons.close,
                  tooltip: 'Close Panel',
                  theme: theme,
                  onPressed: layoutController.togglePanel,
                ),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: theme.panelBackground,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final entry in _panelBodies.entries)
                    Offstage(
                      offstage: entry.key != layoutState.activePanelTab,
                      child: TickerMode(
                        enabled: entry.key == layoutState.activePanelTab,
                        child: ExcludeFocus(
                          excluding: entry.key != layoutState.activePanelTab,
                          child: entry.value,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTab({
    required PanelTab tab,
    required bool isSelected,
    required EditorThemeData theme,
    required DiagnosticsService diagnosticsService,
    required ExecutionController executionController,
    required VoidCallback onTap,
  }) {
    final title = switch (tab) {
      PanelTab.problems => 'PROBLEMS',
      PanelTab.output => 'OUTPUT',
      PanelTab.terminal => 'TERMINAL',
      PanelTab.debugConsole => 'DEBUG CONSOLE',
    };
    final badge = switch (tab) {
      PanelTab.problems when diagnosticsService.totalProblems > 0 =>
        diagnosticsService.totalProblems.toString(),
      PanelTab.output when executionController.isRunning => 'RUNNING',
      _ => null,
    };
    final badgeColor = switch (tab) {
      PanelTab.problems when diagnosticsService.totalErrors > 0 =>
        theme.diagnosticError,
      PanelTab.problems when diagnosticsService.totalWarnings > 0 =>
        theme.diagnosticWarning,
      PanelTab.problems when diagnosticsService.totalProblems > 0 =>
        theme.diagnosticInformation,
      PanelTab.output when executionController.isRunning => const Color(
        0xFF23D18B,
      ),
      _ => null,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      label: badge == null ? title : '$title, $badge',
      child: Tooltip(
        message: title,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              border: isSelected
                  ? Border(
                      bottom: BorderSide(color: theme.accentColor, width: 2),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? theme.panelTitleActive
                        : theme.panelTitleInactive,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.45,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          badgeColor?.withValues(alpha: 0.18) ?? Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                      border: badgeColor == null
                          ? null
                          : Border.all(
                              color: badgeColor.withValues(alpha: 0.45),
                              width: 0.7,
                            ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: badgeColor ?? theme.panelForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(
    PanelTab tab,
    DiagnosticsService diagnosticsService,
    ExecutionController executionController,
    OutputService outputService,
  ) {
    switch (tab) {
      case PanelTab.terminal:
        return const TerminalPanelView();
      case PanelTab.problems:
        return ProblemsView(diagnosticsService: diagnosticsService);
      case PanelTab.output:
        return ExecutionOutputView(outputService: outputService);
      case PanelTab.debugConsole:
        return const _DebugConsoleUnavailableView();
    }
  }

  Widget _buildActionIcon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required EditorThemeData theme,
    required VoidCallback onPressed,
  }) => Semantics(
    button: true,
    label: tooltip,
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 16),
      color: theme.panelForeground.withValues(alpha: 0.75),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
    ),
  );
}

class _DebugConsoleUnavailableView extends StatelessWidget {
  const _DebugConsoleUnavailableView();

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bug_report_outlined,
              size: 32,
              color: theme.panelForeground.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'No debug session is available.',
              style: TextStyle(
                color: theme.panelForeground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'A Debug Adapter is not connected, so expression evaluation is unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.panelForeground.withValues(alpha: 0.55),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
