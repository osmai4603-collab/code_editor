import 'package:flutter/material.dart';
import '../../../core/execution/execution_controller.dart';
import '../../../core/execution/execution_session.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../layout/controllers/editor_controller.dart';

/// شاشة مخرجات تنفيذ البرامج في اللوحة السفلية (Execution Output View)
class ExecutionOutputView extends StatefulWidget {
  final ExecutionController executionController;

  const ExecutionOutputView({
    super.key,
    required this.executionController,
  });

  @override
  State<ExecutionOutputView> createState() => _ExecutionOutputViewState();
}

class _ExecutionOutputViewState extends State<ExecutionOutputView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.executionController.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.executionController.removeListener(_scrollToBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final documentsController = EditorDocumentsScope.of(context);
    final activeTab = documentsController.activeTab;

    return ListenableBuilder(
      listenable: widget.executionController,
      builder: (context, _) {
        final session = widget.executionController.activeSession;
        final isRunning = widget.executionController.isRunning;

        return Column(
          children: [
            // شريط أدوات التحكم السريع في التشغيل
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.panelBackground,
                border: Border(
                  bottom: BorderSide(
                    color: theme.panelBorder.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    session != null
                        ? 'Status: ${session.status.name.toUpperCase()}'
                        : 'No active execution',
                    style: TextStyle(
                      color: isRunning ? Colors.greenAccent : theme.panelForeground.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // زر تشغيل الملف النشط
                  _buildToolbarBtn(
                    icon: Icons.play_arrow_rounded,
                    color: Colors.greenAccent,
                    tooltip: activeTab != null ? 'Run ${activeTab.title}' : 'Run Active File',
                    onTap: activeTab != null && !isRunning
                        ? () => widget.executionController.runFile(activeTab.path)
                        : null,
                  ),
                  // زر إيقاف التشغيل
                  _buildToolbarBtn(
                    icon: Icons.stop_rounded,
                    color: Colors.redAccent,
                    tooltip: 'Stop Execution',
                    onTap: isRunning ? widget.executionController.stopExecution : null,
                  ),
                  // زر مسح المخرجات
                  _buildToolbarBtn(
                    icon: Icons.clear_all_rounded,
                    color: theme.panelForeground.withValues(alpha: 0.7),
                    tooltip: 'Clear Output',
                    onTap: session != null && session.lines.isNotEmpty
                        ? widget.executionController.clearOutput
                        : null,
                  ),
                ],
              ),
            ),

            // قائمة سطور المخرجات
            Expanded(
              child: session == null || session.lines.isEmpty
                  ? Center(
                      child: Text(
                        'Select a file and click Run to see execution output here.',
                        style: TextStyle(
                          color: theme.panelForeground.withValues(alpha: 0.4),
                          fontSize: 12.5,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: session.lines.length,
                      itemBuilder: (context, index) {
                        final line = session.lines[index];
                        return _buildOutputLineWidget(line, theme);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbarBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Icon(
            icon,
            size: 16,
            color: onTap != null ? color : Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _buildOutputLineWidget(ExecutionOutputLine line, EditorThemeData theme) {
    Color textColor;
    FontStyle fontStyle = FontStyle.normal;

    switch (line.type) {
      case OutputLineType.stdout:
        textColor = theme.panelForeground.withValues(alpha: 0.9);
        break;
      case OutputLineType.stderr:
        textColor = const Color(0xFFFF6B6B);
        break;
      case OutputLineType.systemInfo:
        textColor = theme.accentColor;
        fontStyle = FontStyle.italic;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: SelectableText(
        line.text,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 12,
          fontStyle: fontStyle,
        ),
      ),
    );
  }
}
