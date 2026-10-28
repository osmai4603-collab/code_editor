import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/terminal/input/terminal_input_handler.dart';
import '../../../../core/terminal/models/terminal_color_palette.dart';
import '../../../../core/terminal/services/terminal_config_service.dart';
import '../../../../core/terminal/services/terminal_service.dart';
import '../../../../core/theme/editor_theme.dart';
import 'terminal_renderer.dart';
import 'terminal_selection.dart';
import 'terminal_toolbar.dart';

class TerminalInstanceView extends StatefulWidget {
  final TerminalInstance instance;
  final TerminalService terminalService;
  final TerminalConfigService config;

  const TerminalInstanceView({
    required this.instance,
    required this.terminalService,
    required this.config,
    super.key,
  });

  @override
  State<TerminalInstanceView> createState() => _TerminalInstanceViewState();
}

class _TerminalInstanceViewState extends State<TerminalInstanceView> {
  late final TerminalInputHandler _inputHandler;
  final FocusNode _focusNode = FocusNode();
  final TerminalSelection _selection = TerminalSelection();
  Size _charSize = Size.zero;
  int _scrollOffset = 0;
  bool _resizeScheduled = false;

  @override
  void initState() {
    super.initState();
    _inputHandler = TerminalInputHandler(
      processManager: widget.instance.processManager,
      state: widget.instance.state,
    );
    widget.instance.state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _charSize = widget.config.measureCharSize(context);
        _scheduleResize(constraints);
        final palette = TerminalColorPalette(
          ansiColors: theme.terminalAnsiColors,
          foreground: theme.terminalForeground,
          background: theme.terminalBackground,
          cursor: theme.terminalCursor,
          selectionBackground: theme.terminalSelectionBackground,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _focusNode.requestFocus,
                onPanStart: _onSelectionStart,
                onPanUpdate: _onSelectionUpdate,
                onPanEnd: (_) {
                  _selection.end();
                  if (widget.config.copyOnSelection) _copySelection();
                },
                child: Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) =>
                      _inputHandler.handleKeyEvent(event),
                  child: Listener(
                    onPointerSignal: _onScroll,
                    child: CustomPaint(
                      painter: TerminalRenderer(
                        state: widget.instance.state,
                        config: widget.config,
                        palette: palette,
                        charSize: _charSize,
                        scrollOffset: _scrollOffset,
                        selection: _selection,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 4,
              child: TerminalToolbar(
                instance: widget.instance,
                terminalService: widget.terminalService,
                theme: theme,
                selection: _selection,
                scrollOffset: _scrollOffset,
              ),
            ),
          ],
        );
      },
    );
  }

  void _scheduleResize(BoxConstraints constraints) {
    if (_resizeScheduled || _charSize.width <= 0 || _charSize.height <= 0) {
      return;
    }
    final cols = (constraints.maxWidth / _charSize.width).floor().clamp(1, 500);
    final rows = (constraints.maxHeight / _charSize.height).floor().clamp(
      1,
      200,
    );
    if (cols == widget.instance.state.buffer.cols &&
        rows == widget.instance.state.buffer.rows) {
      return;
    }
    _resizeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resizeScheduled = false;
      if (!mounted) return;
      widget.instance.processManager.resize(cols, rows);
    });
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    setState(() {
      final delta = event.scrollDelta.dy > 0 ? 3 : -3;
      _scrollOffset = (_scrollOffset + delta)
          .clamp(0, widget.instance.state.buffer.scrollbackLength)
          .toInt();
    });
  }

  void _onSelectionStart(DragStartDetails details) {
    final cell = _cellAt(details.localPosition);
    _selection.start(cell.$1, cell.$2);
    setState(() {});
  }

  void _onSelectionUpdate(DragUpdateDetails details) {
    final cell = _cellAt(details.localPosition);
    _selection.update(cell.$1, cell.$2);
    setState(() {});
  }

  (int, int) _cellAt(Offset position) {
    final row = (position.dy / _charSize.height).floor();
    final col = (position.dx / _charSize.width).floor();
    return (
      row.clamp(0, widget.instance.state.buffer.rows - 1),
      col.clamp(0, widget.instance.state.buffer.cols - 1),
    );
  }

  Future<void> _copySelection() async {
    final text = _selection.getSelectedText(
      widget.instance.state.buffer,
      scrollOffset: _scrollOffset,
    );
    if (text.isNotEmpty) await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  void dispose() {
    widget.instance.state.removeListener(_onStateChanged);
    _focusNode.dispose();
    super.dispose();
  }
}
