import 'package:flutter/widgets.dart';

class StableEditorScrollState {
  final double cursorDistanceFromViewportTop;

  const StableEditorScrollState({
    required this.cursorDistanceFromViewportTop,
  });

  static StableEditorScrollState? capture({
    required ScrollController scrollController,
    required int cursorLine,
    required double lineHeight,
  }) {
    if (!scrollController.hasClients || lineHeight <= 0) return null;
    return StableEditorScrollState(
      cursorDistanceFromViewportTop:
          cursorLine * lineHeight - scrollController.offset,
    );
  }

  void restore({
    required ScrollController scrollController,
    required int cursorLine,
    required double lineHeight,
  }) {
    if (!scrollController.hasClients || lineHeight <= 0) return;
    final position =
        cursorLine * lineHeight - cursorDistanceFromViewportTop;
    scrollController.jumpTo(
      position
          .clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          )
          .toDouble(),
    );
  }
}
