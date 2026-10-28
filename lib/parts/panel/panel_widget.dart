import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/lsp/diagnostics/diagnostics_service.dart';
import 'package:code_editor/core/terminal/services/terminal_scope.dart';
import 'package:code_editor/core/terminal/services/terminal_service.dart';
import 'package:flutter/material.dart';
import '../../core/theme/editor_theme.dart';
import '../../layout/controllers/layout_controller.dart';
import '../../layout/controllers/lsp_and_execution_scope.dart';
import '../../layout/models/layout_state.dart';
import 'views/execution_output_view.dart';
import 'views/problems_view.dart';
import 'views/terminal/terminal_panel_view.dart';

/// اللوحة السفلية (Panel) وتشمل الطرفية وسجل المخرجات وقائمة الأخطاء
class PanelWidget extends StatelessWidget {
  const PanelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final layoutState = layoutController.state;
    final diagnosticsService = DiagnosticsScope.of(context);
    final executionController = ExecutionScope.of(context);
    final terminalService = TerminalScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.panelBackground,
        border: Border(top: BorderSide(color: theme.panelBorder, width: 1.0)),
      ),
      child: Column(
        children: [
          // شريط عناوين تبويبات اللوحة السفلية
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.panelBorder.withValues(alpha: 0.5),
                  width: 1.0,
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
                        _buildPanelTab(
                          title: 'PROBLEMS',
                          badge: '${diagnosticsService.totalProblems}',
                          badgeColor: diagnosticsService.totalErrors > 0
                              ? Colors.redAccent
                              : (diagnosticsService.totalWarnings > 0
                                    ? Colors.amberAccent
                                    : null),
                          isSelected:
                              layoutState.activePanelTab == PanelTab.problems,
                          theme: theme,
                          onTap: () => layoutController.selectPanelTab(
                            PanelTab.problems,
                          ),
                        ),
                        _buildPanelTab(
                          title: 'OUTPUT',
                          badge: executionController.isRunning
                              ? 'RUNNING'
                              : null,
                          badgeColor: executionController.isRunning
                              ? Colors.greenAccent
                              : null,
                          isSelected:
                              layoutState.activePanelTab == PanelTab.output,
                          theme: theme,
                          onTap: () =>
                              layoutController.selectPanelTab(PanelTab.output),
                        ),
                        _buildPanelTab(
                          title: 'TERMINAL',
                          isSelected:
                              layoutState.activePanelTab == PanelTab.terminal,
                          theme: theme,
                          onTap: () => layoutController.selectPanelTab(
                            PanelTab.terminal,
                          ),
                        ),
                        _buildPanelTab(
                          title: 'DEBUG CONSOLE',
                          isSelected:
                              layoutState.activePanelTab ==
                              PanelTab.debugConsole,
                          theme: theme,
                          onTap: () => layoutController.selectPanelTab(
                            PanelTab.debugConsole,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // أزرار التحكم باللوحة
                _buildActionIcon(
                  Icons.add,
                  'New Terminal',
                  theme,
                  () => _createTerminal(
                    context,
                    terminalService,
                    layoutController,
                  ),
                ),
                _buildActionIcon(
                  layoutState.isPanelMaximized
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  layoutState.isPanelMaximized
                      ? 'Restore Panel Size'
                      : 'Maximize Panel Size',
                  theme,
                  layoutController.togglePanelMaximized,
                ),
                _buildActionIcon(
                  Icons.close,
                  'Close Panel',
                  theme,
                  layoutController.togglePanel,
                ),
              ],
            ),
          ),

          // محتوى اللوحة السفلية النشطة
          Expanded(
            child: _buildTabBody(
              layoutState.activePanelTab,
              theme,
              diagnosticsService,
              executionController,
              terminalService,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTab({
    required String title,
    String? badge,
    Color? badgeColor,
    required bool isSelected,
    required EditorThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: isSelected
              ? Border(bottom: BorderSide(color: theme.accentColor, width: 2.0))
              : null,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? theme.panelTitleActive
                    : theme.panelTitleInactive,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
            if (badge != null && badge != '0') ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor?.withValues(alpha: 0.25) ?? Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  border: badgeColor != null
                      ? Border.all(
                          color: badgeColor.withValues(alpha: 0.5),
                          width: 0.8,
                        )
                      : null,
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(
    PanelTab tab,
    EditorThemeData theme,
    DiagnosticsService diagnosticsService,
    ExecutionController executionController,
    TerminalService terminalService,
  ) {
    switch (tab) {
      case PanelTab.terminal:
        return const TerminalPanelView();
      case PanelTab.problems:
        return ProblemsView(diagnosticsService: diagnosticsService);
      case PanelTab.output:
        return ExecutionOutputView(executionController: executionController);
      case PanelTab.debugConsole:
        return Center(
          child: Text(
            'Debug console is ready.',
            style: TextStyle(
              color: theme.panelForeground.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        );
    }
  }

  Future<void> _createTerminal(
    BuildContext context,
    TerminalService terminalService,
    WorkbenchLayoutController layoutController,
  ) async {
    layoutController.selectPanelTab(PanelTab.terminal);
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

Widget _buildActionIcon(
  IconData icon,
  String tooltip,
  EditorThemeData theme,
  VoidCallback onPressed,
) {
  return Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(
          icon,
          size: 14,
          color: theme.panelForeground.withValues(alpha: 0.7),
        ),
      ),
    ),
  );
}
