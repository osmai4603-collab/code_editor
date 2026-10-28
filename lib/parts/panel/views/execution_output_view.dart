import 'package:flutter/material.dart';

import '../../../core/execution/execution_session.dart';
import '../../../core/output/output_service.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../layout/controllers/editor_controller.dart';
import '../../../models/editor_tab_item.dart';

class ExecutionOutputView extends StatefulWidget {
  final OutputService outputService;

  const ExecutionOutputView({super.key, required this.outputService});

  @override
  State<ExecutionOutputView> createState() => _ExecutionOutputViewState();
}

class _ExecutionOutputViewState extends State<ExecutionOutputView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _lastSelectedChannelId;
  bool _shouldFollowOutput = true;

  @override
  void initState() {
    super.initState();
    _lastSelectedChannelId = widget.outputService.selectedChannel?.id;
    widget.outputService.addListener(_handleOutputChanged);
    _scrollController.addListener(_handleScrollChanged);
  }

  @override
  void didUpdateWidget(covariant ExecutionOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outputService != widget.outputService) {
      oldWidget.outputService.removeListener(_handleOutputChanged);
      widget.outputService.addListener(_handleOutputChanged);
      _lastSelectedChannelId = widget.outputService.selectedChannel?.id;
      _shouldFollowOutput = true;
    }
  }

  @override
  void dispose() {
    widget.outputService.removeListener(_handleOutputChanged);
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleOutputChanged() {
    final selectedId = widget.outputService.selectedChannel?.id;
    if (selectedId != _lastSelectedChannelId) {
      _lastSelectedChannelId = selectedId;
      _shouldFollowOutput = true;
    }
    if (_shouldFollowOutput) _scrollToBottom();
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _shouldFollowOutput = position.maxScrollExtent - position.pixels <= 28;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_shouldFollowOutput || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final documentsController = EditorDocumentsScope.of(context);
    final activeTab = documentsController.activeTab;

    return ListenableBuilder(
      listenable: widget.outputService,
      builder: (context, _) {
        final channels = widget.outputService.channels;
        final selectedChannel = widget.outputService.selectedChannel;
        final selectedSession = selectedChannel?.session;
        final isRunning = widget.outputService.executionController.isRunning;
        final query = _searchController.text.trim().toLowerCase();
        final lines =
            selectedSession?.lines
                .where(
                  (line) =>
                      query.isEmpty || line.text.toLowerCase().contains(query),
                )
                .toList(growable: false) ??
            const <ExecutionOutputLine>[];

        return Column(
          children: [
            _buildToolbar(
              theme,
              channels,
              selectedChannel,
              selectedSession,
              activeTab,
              isRunning,
            ),
            Expanded(
              child: Stack(
                children: [
                  if (selectedSession == null)
                    _emptyState(
                      theme,
                      'Run a file to start an execution output session.',
                    )
                  else if (lines.isEmpty)
                    _emptyState(
                      theme,
                      selectedSession.lines.isEmpty
                          ? 'This execution has no output yet.'
                          : 'No output matches the current search.',
                      action: selectedSession.lines.isEmpty
                          ? null
                          : () {
                              _searchController.clear();
                              setState(() {});
                            },
                    )
                  else
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 36),
                      itemCount: lines.length,
                      itemBuilder: (context, index) =>
                          _buildOutputLineWidget(lines[index], theme),
                    ),
                  if (lines.isNotEmpty && !_shouldFollowOutput)
                    PositionedDirectional(
                      end: 12,
                      bottom: 8,
                      child: TextButton.icon(
                        onPressed: () {
                          _shouldFollowOutput = true;
                          _scrollToBottom();
                        },
                        icon: const Icon(Icons.arrow_downward, size: 14),
                        label: const Text('Scroll to bottom'),
                        style: TextButton.styleFrom(
                          backgroundColor: theme.panelBackground,
                          foregroundColor: theme.panelForeground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(
    EditorThemeData theme,
    List<OutputChannel> channels,
    OutputChannel? selectedChannel,
    ExecutionSession? selectedSession,
    EditorTabItem? activeTab,
    bool isRunning,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.panelBorder.withValues(alpha: 0.4)),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              _statusLabel(selectedSession, isRunning),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _statusColor(selectedSession, isRunning, theme),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (channels.isNotEmpty)
            SizedBox(
              width: 170,
              height: 30,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedChannel?.id,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: theme.panelBackground,
                  style: TextStyle(color: theme.panelForeground, fontSize: 11),
                  hint: const Text('Select execution'),
                  items: channels.reversed
                      .map(
                        (channel) => DropdownMenuItem(
                          value: channel.id,
                          child: Text(
                            channel.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    widget.outputService.selectChannel(id);
                    _shouldFollowOutput = true;
                    _scrollToBottom();
                  },
                ),
              ),
            ),
          SizedBox(
            width: 170,
            height: 30,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.panelForeground, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Search output',
                hintStyle: TextStyle(
                  color: theme.panelForeground.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
                prefixIcon: const Icon(Icons.search, size: 15),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 13),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                isDense: true,
                filled: true,
                fillColor: theme.editorBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.panelBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.panelBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.accentColor),
                ),
              ),
            ),
          ),
          _buildToolbarButton(
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF23D18B),
            tooltip: activeTab == null
                ? 'Open a file before running'
                : 'Run ${activeTab.title}',
            onPressed: activeTab != null && !isRunning
                ? () => widget.outputService.executionController.runFile(
                    activeTab.path,
                  )
                : null,
          ),
          _buildToolbarButton(
            icon: Icons.stop_rounded,
            color: theme.diagnosticError,
            tooltip: 'Stop execution',
            onPressed: isRunning
                ? widget.outputService.executionController.stopExecution
                : null,
          ),
          _buildToolbarButton(
            icon: Icons.clear_all_rounded,
            color: theme.panelForeground,
            tooltip: 'Clear selected output',
            onPressed:
                selectedSession != null && selectedSession.lines.isNotEmpty
                ? () => widget.outputService.clearChannel(selectedChannel!.id)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: 17),
    color: color,
    disabledColor: themeDisabledColor(color),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    padding: const EdgeInsets.all(4),
  );

  Widget _emptyState(
    EditorThemeData theme,
    String message, {
    VoidCallback? action,
  }) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.panelForeground.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        if (action != null)
          TextButton(onPressed: action, child: const Text('Clear search')),
      ],
    ),
  );

  Widget _buildOutputLineWidget(
    ExecutionOutputLine line,
    EditorThemeData theme,
  ) {
    final (textColor, fontStyle) = switch (line.type) {
      OutputLineType.stdout => (
        theme.panelForeground.withValues(alpha: 0.9),
        FontStyle.normal,
      ),
      OutputLineType.stderr => (theme.diagnosticError, FontStyle.normal),
      OutputLineType.systemInfo => (theme.accentColor, FontStyle.italic),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: SelectableText(
        line.text,
        style: TextStyle(
          color: textColor,
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          fontStyle: fontStyle,
        ),
      ),
    );
  }

  String _statusLabel(ExecutionSession? session, bool isRunning) {
    if (session == null) return 'No execution';
    if (isRunning && session.status == ExecutionStatus.running) {
      return 'RUNNING';
    }
    final exitCode = session.exitCode;
    return exitCode == null
        ? session.status.name.toUpperCase()
        : '${session.status.name.toUpperCase()} (exit $exitCode)';
  }

  Color _statusColor(
    ExecutionSession? session,
    bool isRunning,
    EditorThemeData theme,
  ) {
    if (isRunning && session?.status == ExecutionStatus.running) {
      return const Color(0xFF23D18B);
    }
    if (session?.status == ExecutionStatus.failed) return theme.diagnosticError;
    if (session?.status == ExecutionStatus.completed) {
      return const Color(0xFF23D18B);
    }
    return theme.panelForeground.withValues(alpha: 0.55);
  }

  Color themeDisabledColor(Color color) => color.withValues(alpha: 0.3);
}
