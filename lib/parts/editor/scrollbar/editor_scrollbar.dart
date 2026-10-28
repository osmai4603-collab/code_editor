import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/editor_theme.dart';
import 'editor_scrollbar_state.dart';

enum EditorScrollbarVisibility { auto, visible, hidden }

class EditorScrollBehavior extends ScrollBehavior {
  const EditorScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class EditorScrollbar extends StatefulWidget {
  final Axis axis;
  final ScrollController controller;
  final EditorScrollbarVisibility visibility;
  final double thickness;
  final double minThumbExtent;

  const EditorScrollbar({
    super.key,
    required this.axis,
    required this.controller,
    this.visibility = EditorScrollbarVisibility.auto,
    this.thickness = 12,
    this.minThumbExtent = 20,
  }) : assert(thickness > 0),
       assert(minThumbExtent > 0);

  @override
  State<EditorScrollbar> createState() => _EditorScrollbarState();
}

class _EditorScrollbarState extends State<EditorScrollbar> {
  static const _visibilityDuration = Duration(milliseconds: 900);

  Timer? _visibilityTimer;
  bool _isHovered = false;
  bool _isDragging = false;
  bool _isTemporarilyVisible = false;
  double? _dragGrabOffset;

  bool get _isVertical => widget.axis == Axis.vertical;

  bool get _isVisible =>
      widget.visibility == EditorScrollbarVisibility.visible ||
      _isHovered ||
      _isDragging ||
      _isTemporarilyVisible;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(EditorScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
    if (oldWidget.visibility != widget.visibility &&
        widget.visibility != EditorScrollbarVisibility.auto) {
      _visibilityTimer?.cancel();
      _isTemporarilyVisible = false;
    }
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) return;
    setState(() {
      if (widget.visibility == EditorScrollbarVisibility.auto) {
        _isTemporarilyVisible = true;
      }
    });
    if (widget.visibility == EditorScrollbarVisibility.auto) {
      _visibilityTimer?.cancel();
      _visibilityTimer = Timer(_visibilityDuration, () {
        if (mounted && !_isHovered && !_isDragging) {
          setState(() => _isTemporarilyVisible = false);
        }
      });
    }
  }

  void _handleMetricsChanged(ScrollMetricsNotification notification) {
    if (mounted) setState(() {});
  }

  void _handleHover(bool isHovered) {
    if (_isHovered == isHovered) return;
    setState(() => _isHovered = isHovered);
    if (!isHovered && !_isDragging) _handleScroll();
  }

  EditorScrollbarThumbGeometry? _geometry(double trackExtent) {
    if (!widget.controller.hasClients) {
      if (widget.visibility != EditorScrollbarVisibility.visible) return null;
      return EditorScrollbarThumbGeometry.calculate(
        viewportExtent: trackExtent,
        maxScrollExtent: 0,
        scrollOffset: 0,
        trackExtent: trackExtent,
        minThumbExtent: widget.minThumbExtent,
      );
    }
    final position = widget.controller.position;
    if (!position.hasContentDimensions) return null;
    return EditorScrollbarThumbGeometry.calculate(
      viewportExtent: position.viewportDimension,
      maxScrollExtent: position.maxScrollExtent,
      scrollOffset: position.pixels,
      trackExtent: trackExtent,
      minThumbExtent: widget.minThumbExtent,
    );
  }

  double _axisOffset(Offset offset) => _isVertical ? offset.dy : offset.dx;

  void _handleTrackTap(TapDownDetails details, double trackExtent) {
    if (!widget.controller.hasClients) return;
    final geometry = _geometry(trackExtent);
    if (geometry == null || geometry.maxScrollExtent == 0) return;

    final tapOffset = _axisOffset(details.localPosition);
    final thumbEnd = geometry.thumbOffset + geometry.thumbExtent;
    if (tapOffset >= geometry.thumbOffset && tapOffset <= thumbEnd) return;

    final position = widget.controller.position;
    final pageDelta = tapOffset < geometry.thumbOffset
        ? -position.viewportDimension
        : position.viewportDimension;
    widget.controller.jumpTo(
      (position.pixels + pageDelta)
          .clamp(0, position.maxScrollExtent)
          .toDouble(),
    );
  }

  void _handleDragStart(DragStartDetails details, double trackExtent) {
    final geometry = _geometry(trackExtent);
    if (geometry == null) return;
    final pointerOffset = _axisOffset(details.localPosition);
    if (pointerOffset < geometry.thumbOffset ||
        pointerOffset > geometry.thumbOffset + geometry.thumbExtent) {
      return;
    }

    setState(() {
      _isDragging = true;
      _dragGrabOffset = pointerOffset - geometry.thumbOffset;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double trackExtent) {
    final grabOffset = _dragGrabOffset;
    if (grabOffset == null || !widget.controller.hasClients) return;
    final geometry = _geometry(trackExtent);
    if (geometry == null) return;
    final thumbOffset = _axisOffset(details.localPosition) - grabOffset;
    widget.controller.jumpTo(geometry.scrollOffsetForThumbOffset(thumbOffset));
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _dragGrabOffset = null;
    });
    _handleScroll();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visibility == EditorScrollbarVisibility.hidden) {
      return const SizedBox.shrink();
    }
    final theme = EditorTheme.of(context);
    final trackColor = theme.editorScrollbarTrack;
    final thumbColor = _isDragging
        ? theme.editorScrollbarThumbActive
        : _isHovered
        ? theme.editorScrollbarThumbHover
        : theme.editorScrollbarThumb;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _handleMetricsChanged(notification);
        return false;
      },
      child: MouseRegion(
        cursor: _isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.basic,
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackExtent = _isVertical
                ? constraints.maxHeight
                : constraints.maxWidth;
            final geometry = _geometry(trackExtent);
            final isVisible =
                widget.visibility == EditorScrollbarVisibility.visible ||
                (_isVisible &&
                    geometry != null &&
                    geometry.maxScrollExtent > 0);

            return AnimatedOpacity(
              opacity: isVisible ? 1 : 0.01,
              duration: const Duration(milliseconds: 150),
              child: Semantics(
                label: !isVisible
                    ? null
                    : _isVertical
                    ? 'Editor vertical scrollbar'
                    : 'Editor horizontal scrollbar',
                value: isVisible && widget.controller.hasClients
                    ? '${(widget.controller.position.pixels).round()}'
                    : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  dragStartBehavior: DragStartBehavior.down,
                  onTapDown: (details) => _handleTrackTap(details, trackExtent),
                  onVerticalDragStart: _isVertical
                      ? (details) => _handleDragStart(details, trackExtent)
                      : null,
                  onVerticalDragUpdate: _isVertical
                      ? (details) => _handleDragUpdate(details, trackExtent)
                      : null,
                  onVerticalDragEnd: _isVertical ? _handleDragEnd : null,
                  onHorizontalDragStart: !_isVertical
                      ? (details) => _handleDragStart(details, trackExtent)
                      : null,
                  onHorizontalDragUpdate: !_isVertical
                      ? (details) => _handleDragUpdate(details, trackExtent)
                      : null,
                  onHorizontalDragEnd: !_isVertical ? _handleDragEnd : null,
                  child: CustomPaint(
                    painter: _EditorScrollbarPainter(
                      axis: widget.axis,
                      geometry: geometry,
                      trackColor: trackColor,
                      thumbColor: thumbColor,
                      thickness: widget.thickness,
                      showTrack:
                          widget.visibility ==
                              EditorScrollbarVisibility.visible ||
                          _isHovered ||
                          _isDragging,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditorScrollbarPainter extends CustomPainter {
  final Axis axis;
  final EditorScrollbarThumbGeometry? geometry;
  final Color trackColor;
  final Color thumbColor;
  final double thickness;
  final bool showTrack;

  const _EditorScrollbarPainter({
    required this.axis,
    required this.geometry,
    required this.trackColor,
    required this.thumbColor,
    required this.thickness,
    required this.showTrack,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thumb = geometry;
    if (thumb == null) return;

    final isVertical = axis == Axis.vertical;
    final extent = isVertical ? size.height : size.width;
    final crossExtent = isVertical ? size.width : size.height;
    if (extent <= 0 || crossExtent <= 0) return;
    final thumbExtent = thumb.thumbExtent.clamp(0, extent).toDouble();
    final thumbOffset = thumb.thumbOffset
        .clamp(0, extent - thumbExtent)
        .toDouble();
    final paintedThickness = (showTrack ? thickness : 4)
        .clamp(2, crossExtent)
        .toDouble();
    final crossOffset = (crossExtent - paintedThickness) / 2;
    final trackRect = isVertical
        ? Rect.fromLTWH(crossOffset, 0, paintedThickness, extent)
        : Rect.fromLTWH(0, crossOffset, extent, paintedThickness);
    final thumbRect = isVertical
        ? Rect.fromLTWH(crossOffset, thumbOffset, paintedThickness, thumbExtent)
        : Rect.fromLTWH(
            thumbOffset,
            crossOffset,
            thumbExtent,
            paintedThickness,
          );

    if (showTrack) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
        Paint()..color = trackColor,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, const Radius.circular(4)),
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_EditorScrollbarPainter oldDelegate) =>
      axis != oldDelegate.axis ||
      geometry != oldDelegate.geometry ||
      trackColor != oldDelegate.trackColor ||
      thumbColor != oldDelegate.thumbColor ||
      thickness != oldDelegate.thickness ||
      showTrack != oldDelegate.showTrack;
}
