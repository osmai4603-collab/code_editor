import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/lsp/diagnostics/diagnostic_range_utils.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';

@immutable
class DiagnosticsOverviewRulerMarker {
  final int startLine;
  final int endLine;
  final DiagnosticSeverity severity;

  const DiagnosticsOverviewRulerMarker({
    required this.startLine,
    required this.endLine,
    required this.severity,
  });

  @override
  bool operator ==(Object other) =>
      other is DiagnosticsOverviewRulerMarker &&
      startLine == other.startLine &&
      endLine == other.endLine &&
      severity == other.severity;

  @override
  int get hashCode => Object.hash(startLine, endLine, severity);
}

class DiagnosticsOverviewRulerLayout {
  const DiagnosticsOverviewRulerLayout._();

  static List<DiagnosticSeverity?> buildLineSeverities(
    List<DiagnosticItem> diagnostics,
    int lineCount,
  ) {
    final safeLineCount = lineCount < 1 ? 1 : lineCount;
    final severities = List<DiagnosticSeverity?>.filled(safeLineCount, null);
    for (final diagnostic in diagnostics) {
      final start = diagnostic.range.start.line
          .clamp(0, safeLineCount - 1)
          .toInt();
      final end = DiagnosticRangeUtils.lastCoveredLine(
        diagnostic.range,
      ).clamp(start, safeLineCount - 1).toInt();
      for (var line = start; line <= end; line++) {
        final current = severities[line];
        if (current == null ||
            DiagnosticRangeUtils.severityRank(diagnostic.severity) >
                DiagnosticRangeUtils.severityRank(current)) {
          severities[line] = diagnostic.severity;
        }
      }
    }
    return List.unmodifiable(severities);
  }

  static List<DiagnosticsOverviewRulerMarker> buildMarkers(
    List<DiagnosticItem> diagnostics,
    int lineCount,
  ) {
    final severities = buildLineSeverities(diagnostics, lineCount);
    final markers = <DiagnosticsOverviewRulerMarker>[];
    var startLine = 0;
    var currentSeverity = severities.first;
    for (var line = 1; line <= severities.length; line++) {
      final nextSeverity = line == severities.length ? null : severities[line];
      if (nextSeverity == currentSeverity) continue;
      if (currentSeverity != null) {
        markers.add(
          DiagnosticsOverviewRulerMarker(
            startLine: startLine,
            endLine: line - 1,
            severity: currentSeverity,
          ),
        );
      }
      startLine = line;
      currentSeverity = nextSeverity;
    }
    return List.unmodifiable(markers);
  }

  static Rect markerRect({
    required DiagnosticsOverviewRulerMarker marker,
    required Size size,
    required int lineCount,
    required double lineHeight,
    required double documentExtent,
    double minHeight = 2,
  }) {
    if (size.isEmpty || lineHeight <= 0 || documentExtent <= 0) {
      return Rect.zero;
    }
    final safeLineCount = lineCount < 1 ? 1 : lineCount;
    final start = marker.startLine.clamp(0, safeLineCount - 1).toInt();
    final end = marker.endLine.clamp(start, safeLineCount - 1).toInt();
    final top = (start * lineHeight / documentExtent * size.height)
        .clamp(0.0, size.height)
        .toDouble();
    final naturalBottom =
        ((end + 1) * lineHeight / documentExtent * size.height)
            .clamp(0.0, size.height)
            .toDouble();
    final bottom = naturalBottom < top + minHeight
        ? (top + minHeight).clamp(0.0, size.height).toDouble()
        : naturalBottom;
    return Rect.fromLTRB(0, top, size.width, bottom);
  }
}

class DiagnosticsOverviewRuler extends StatelessWidget {
  final List<DiagnosticItem> diagnostics;
  final int lineCount;
  final double lineHeight;
  final double documentExtent;

  const DiagnosticsOverviewRuler({
    super.key,
    required this.diagnostics,
    required this.lineCount,
    required this.lineHeight,
    required this.documentExtent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final markers = DiagnosticsOverviewRulerLayout.buildMarkers(
      diagnostics,
      lineCount,
    );
    return Semantics(
      label: 'Diagnostics overview ruler, ${diagnostics.length} diagnostics',
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DiagnosticsOverviewRulerPainter(
            markers: markers,
            lineCount: lineCount,
            lineHeight: lineHeight,
            documentExtent: documentExtent,
            theme: theme,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _DiagnosticsOverviewRulerPainter extends CustomPainter {
  final List<DiagnosticsOverviewRulerMarker> markers;
  final int lineCount;
  final double lineHeight;
  final double documentExtent;
  final EditorThemeData theme;

  const _DiagnosticsOverviewRulerPainter({
    required this.markers,
    required this.lineCount,
    required this.lineHeight,
    required this.documentExtent,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final marker in markers) {
      final rect = DiagnosticsOverviewRulerLayout.markerRect(
        marker: marker,
        size: size,
        lineCount: lineCount,
        lineHeight: lineHeight,
        documentExtent: documentExtent,
      );
      if (rect.isEmpty) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        Paint()
          ..color = theme.diagnosticColor(marker.severity)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagnosticsOverviewRulerPainter oldDelegate) =>
      !listEquals(markers, oldDelegate.markers) ||
      lineCount != oldDelegate.lineCount ||
      lineHeight != oldDelegate.lineHeight ||
      documentExtent != oldDelegate.documentExtent ||
      theme != oldDelegate.theme;
}
