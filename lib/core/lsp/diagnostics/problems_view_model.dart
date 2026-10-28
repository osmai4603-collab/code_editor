import '../protocol/lsp_types.dart';
import 'diagnostics_service.dart';

class ProblemsViewFilter {
  final String query;
  final bool showErrors;
  final bool showWarnings;
  final bool showInformation;
  final bool showHints;
  final bool onlyActiveFile;
  final String? activeFilePath;

  const ProblemsViewFilter({
    this.query = '',
    this.showErrors = true,
    this.showWarnings = true,
    this.showInformation = true,
    this.showHints = true,
    this.onlyActiveFile = false,
    this.activeFilePath,
  });

  bool get isActive =>
      query.trim().isNotEmpty ||
      !showErrors ||
      !showWarnings ||
      !showInformation ||
      !showHints ||
      onlyActiveFile;

  ProblemsViewFilter copyWith({
    String? query,
    bool? showErrors,
    bool? showWarnings,
    bool? showInformation,
    bool? showHints,
    bool? onlyActiveFile,
    String? activeFilePath,
  }) {
    return ProblemsViewFilter(
      query: query ?? this.query,
      showErrors: showErrors ?? this.showErrors,
      showWarnings: showWarnings ?? this.showWarnings,
      showInformation: showInformation ?? this.showInformation,
      showHints: showHints ?? this.showHints,
      onlyActiveFile: onlyActiveFile ?? this.onlyActiveFile,
      activeFilePath: activeFilePath ?? this.activeFilePath,
    );
  }
}

class ProblemsViewModel {
  const ProblemsViewModel._();

  static Map<String, List<DiagnosticItem>> filterAndSort(
    Map<String, List<DiagnosticItem>> diagnostics,
    ProblemsViewFilter filter,
  ) {
    final query = filter.query.trim().toLowerCase();
    final activeUri = filter.activeFilePath == null
        ? null
        : DiagnosticsService.normalizeUri(filter.activeFilePath!);
    final entries = <MapEntry<String, List<DiagnosticItem>>>[];

    for (final entry in diagnostics.entries) {
      if (filter.onlyActiveFile &&
          (activeUri == null ||
              DiagnosticsService.normalizeUri(entry.key) != activeUri)) {
        continue;
      }

      final path = DiagnosticsService.pathForUri(entry.key);
      final items = entry.value.where((item) {
        if (!_isSeverityVisible(item.severity, filter)) return false;
        if (query.isEmpty) return true;
        return [
          path,
          item.message,
          item.source ?? '',
          item.code?.toString() ?? '',
        ].any((value) => value.toLowerCase().contains(query));
      }).toList()..sort(_compareDiagnostics);

      if (items.isNotEmpty) {
        entries.add(MapEntry(entry.key, List.unmodifiable(items)));
      }
    }

    entries.sort((left, right) {
      final leftPath = DiagnosticsService.pathForUri(left.key).toLowerCase();
      final rightPath = DiagnosticsService.pathForUri(right.key).toLowerCase();
      return leftPath.compareTo(rightPath);
    });

    return Map.unmodifiable(Map.fromEntries(entries));
  }

  static bool _isSeverityVisible(
    DiagnosticSeverity severity,
    ProblemsViewFilter filter,
  ) => switch (severity) {
    DiagnosticSeverity.error => filter.showErrors,
    DiagnosticSeverity.warning => filter.showWarnings,
    DiagnosticSeverity.information => filter.showInformation,
    DiagnosticSeverity.hint => filter.showHints,
  };

  static int _compareDiagnostics(DiagnosticItem left, DiagnosticItem right) {
    final line = left.range.start.line.compareTo(right.range.start.line);
    if (line != 0) return line;
    final character = left.range.start.character.compareTo(
      right.range.start.character,
    );
    if (character != 0) return character;
    final severity = left.severity.value.compareTo(right.severity.value);
    if (severity != 0) return severity;
    return left.message.compareTo(right.message);
  }
}
