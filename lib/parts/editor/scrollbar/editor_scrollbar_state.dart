class EditorScrollbarThumbGeometry {
  final double thumbExtent;
  final double thumbOffset;
  final double maxScrollExtent;
  final double trackExtent;

  const EditorScrollbarThumbGeometry({
    required this.thumbExtent,
    required this.thumbOffset,
    required this.maxScrollExtent,
    required this.trackExtent,
  });

  static EditorScrollbarThumbGeometry? calculate({
    required double viewportExtent,
    required double maxScrollExtent,
    required double scrollOffset,
    required double trackExtent,
    double minThumbExtent = 20,
  }) {
    if (!viewportExtent.isFinite ||
        !maxScrollExtent.isFinite ||
        !scrollOffset.isFinite ||
        !trackExtent.isFinite ||
        !minThumbExtent.isFinite ||
        viewportExtent <= 0 ||
        trackExtent <= 0 ||
        minThumbExtent <= 0) {
      return null;
    }

    final safeMaxScrollExtent = maxScrollExtent
        .clamp(0, double.infinity)
        .toDouble();
    final safeScrollOffset = scrollOffset
        .clamp(0, safeMaxScrollExtent)
        .toDouble();
    final contentExtent = viewportExtent + safeMaxScrollExtent;
    final proportionalExtent = contentExtent > 0
        ? trackExtent * viewportExtent / contentExtent
        : trackExtent;
    final thumbExtent = safeMaxScrollExtent == 0
        ? trackExtent
        : proportionalExtent
              .clamp(minThumbExtent.clamp(0, trackExtent), trackExtent)
              .toDouble();
    final thumbTravel = trackExtent - thumbExtent;
    final thumbOffset = safeMaxScrollExtent == 0
        ? 0.0
        : thumbTravel * safeScrollOffset / safeMaxScrollExtent;

    return EditorScrollbarThumbGeometry(
      thumbExtent: thumbExtent,
      thumbOffset: thumbOffset,
      maxScrollExtent: safeMaxScrollExtent,
      trackExtent: trackExtent,
    );
  }

  double scrollOffsetForThumbOffset(double offset) {
    final thumbTravel = trackExtent - thumbExtent;
    if (maxScrollExtent == 0 || thumbTravel <= 0 || !offset.isFinite) {
      return 0;
    }
    return (offset.clamp(0, thumbTravel) / thumbTravel * maxScrollExtent)
        .toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is EditorScrollbarThumbGeometry &&
      other.thumbExtent == thumbExtent &&
      other.thumbOffset == thumbOffset &&
      other.maxScrollExtent == maxScrollExtent &&
      other.trackExtent == trackExtent;

  @override
  int get hashCode =>
      Object.hash(thumbExtent, thumbOffset, maxScrollExtent, trackExtent);
}
