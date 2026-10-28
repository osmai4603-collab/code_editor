import '../protocol/lsp_types.dart';

class DiagnosticRangeUtils {
  const DiagnosticRangeUtils._();

  static int lastCoveredLine(LspRange range) {
    if (range.end.line > range.start.line && range.end.character == 0) {
      return range.end.line - 1;
    }
    return range.end.line < range.start.line
        ? range.start.line
        : range.end.line;
  }

  static List<int>? boundsForLine(
    LspRange range,
    int line,
    int lineLength,
  ) {
    final lastLine = lastCoveredLine(range);
    if (line < range.start.line || line > lastLine) return null;
    final start = line == range.start.line
        ? range.start.character.clamp(0, lineLength).toInt()
        : 0;
    final end = line == lastLine && line == range.end.line
        ? range.end.character.clamp(0, lineLength).toInt()
        : lineLength;
    return [start, end];
  }

  static DiagnosticSeverity? highestSeverityForLineSegment({
    required List<DiagnosticItem> diagnostics,
    required int line,
    required int segmentStart,
    required int segmentEnd,
    required int lineLength,
  }) {
    DiagnosticSeverity? highest;
    for (final diagnostic in diagnostics) {
      final bounds = boundsForLine(diagnostic.range, line, lineLength);
      if (bounds == null) continue;
      final intersects =
          bounds[0] < bounds[1] &&
          bounds[0] < segmentEnd &&
          bounds[1] > segmentStart;
      if (!intersects) continue;

      if (highest == null ||
          _severityRank(diagnostic.severity) > _severityRank(highest)) {
        highest = diagnostic.severity;
      }
    }
    return highest;
  }

  static int severityRank(DiagnosticSeverity severity) =>
      _severityRank(severity);

  static int _severityRank(DiagnosticSeverity severity) {
    switch (severity) {
      case DiagnosticSeverity.error:
        return 4;
      case DiagnosticSeverity.warning:
        return 3;
      case DiagnosticSeverity.information:
        return 2;
      case DiagnosticSeverity.hint:
        return 1;
    }
  }
}
