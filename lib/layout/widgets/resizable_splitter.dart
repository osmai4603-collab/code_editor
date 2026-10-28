import 'package:flutter/material.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/editor_theme.dart';

enum SplitterOrientation {
  horizontal, // فاصل رأسي يتحرك أفقياً (بين النوافذ الجانبية والمحرر)
  vertical,   // فاصل أفقي يتحرك رأسياً (بين المحرر واللوحة السفلية)
}

/// ودجت الفاصل التفاعلي القابل للسحب لتغيير المقاسات (مستوحى من Sash في VS Code)
class ResizableSplitter extends StatefulWidget {
  final SplitterOrientation orientation;
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDoubleTap;

  const ResizableSplitter({
    super.key,
    required this.orientation,
    required this.onDragDelta,
    this.onDragStart,
    this.onDragEnd,
    this.onDoubleTap,
  });

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final isHorizontal = widget.orientation == SplitterOrientation.horizontal;

    final cursor = isHorizontal
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow;

    Color dividerColor = Colors.transparent;
    if (_isDragging) {
      dividerColor = theme.sashActive;
    } else if (_isHovered) {
      dividerColor = theme.sashHover.withValues(alpha: 0.6);
    }

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        onPanStart: (_) {
          setState(() => _isDragging = true);
          widget.onDragStart?.call();
        },
        onPanUpdate: (details) {
          final delta = isHorizontal ? details.delta.dx : details.delta.dy;
          widget.onDragDelta(delta);
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        onPanCancel: () {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        child: Container(
          width: isHorizontal ? EditorConstants.sashThickness : double.infinity,
          height: isHorizontal ? double.infinity : EditorConstants.sashThickness,
          color: dividerColor,
        ),
      ),
    );
  }
}
