import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../protocol/lsp_types.dart';

/// خدمة إدارة المشاكل والتشخيصات المركزية (Diagnostics Service)
///
/// تجمع الأخطاء والتحذيرات الواردة من خوادم LSP المتعددة،
/// وتخطر واجهة المستخدم (لوحة Problems وشريط الحالة والمحرر) بالتحديثات.
class DiagnosticsService extends ChangeNotifier {
  final Map<String, Map<String, _DiagnosticSourceState>> _diagnosticsByUri =
      {};

  /// الحصول على قائمة المشاكل لملف محدد
  List<DiagnosticItem> getForUri(String uri) {
    final sources = _diagnosticsByUri[normalizeUri(uri)];
    if (sources == null || sources.isEmpty) return const [];
    return List.unmodifiable(sources.values.expand((state) => state.items));
  }

  /// جميع المشاكل في مساحة العمل مجمعة
  List<DiagnosticItem> get allDiagnostics {
    final list = <DiagnosticItem>[];
    for (final sources in _diagnosticsByUri.values) {
      for (final state in sources.values) {
        list.addAll(state.items);
      }
    }
    return List.unmodifiable(list);
  }

  /// خريطة الملفات التي تحتوي على مشاكل
  Map<String, List<DiagnosticItem>> get diagnosticsByUri =>
      UnmodifiableMapView({
        for (final uri in _diagnosticsByUri.keys)
          if (getForUri(uri).isNotEmpty) uri: getForUri(uri),
      });

  static String normalizeUri(String uriOrPath) {
    final parsed = Uri.tryParse(uriOrPath);
    if (parsed != null && parsed.scheme == 'file') {
      final path = parsed.toFilePath(windows: _isWindowsPath(parsed.path));
      return Uri.file(
        path,
        windows: _isWindowsPath(path),
      ).normalizePath().toString();
    }
    if (parsed != null &&
        parsed.hasScheme &&
        !_isWindowsPath(uriOrPath)) {
      return parsed.normalizePath().toString();
    }
    return Uri.file(
      uriOrPath,
      windows: _isWindowsPath(uriOrPath),
    ).normalizePath().toString();
  }

  static String pathForUri(String uriOrPath) {
    final parsed = Uri.tryParse(uriOrPath);
    if (parsed == null || parsed.scheme != 'file') return uriOrPath;
    return parsed.toFilePath(windows: _isWindowsPath(parsed.path));
  }

  static bool _isWindowsPath(String path) =>
      RegExp(r'^/?[A-Za-z]:[\\/]').hasMatch(path);

  /// إجمالي عدد الأخطاء الحرجة
  int get totalErrors => allDiagnostics
      .where((d) => d.severity == DiagnosticSeverity.error)
      .length;

  /// إجمالي عدد التحذيرات
  int get totalWarnings => allDiagnostics
      .where((d) => d.severity == DiagnosticSeverity.warning)
      .length;

  /// إجمالي جميع المشاكل
  int get totalProblems => allDiagnostics.length;

  /// تحديث قائمة المشاكل لملف معين
  void updateDiagnostics(String uri, List<DiagnosticItem> items) {
    updateDiagnosticsFromSource('legacy', uri, items);
  }

  void updateDiagnosticsFromSource(
    String sourceId,
    String uri,
    List<DiagnosticItem> items, {
    int? version,
  }) {
    final key = normalizeUri(uri);
    final sources = _diagnosticsByUri.putIfAbsent(key, () => {});
    final previous = sources[sourceId];
    if (version != null &&
        previous?.latestVersion != null &&
        version < previous!.latestVersion!) {
      return;
    }

    sources[sourceId] = _DiagnosticSourceState(
      items: List.unmodifiable(items),
      latestVersion: version ?? previous?.latestVersion,
    );
    notifyListeners();
  }

  /// مسح مشاكل ملف تم إغلاقه أو حذفه
  void clearForUri(
    String uri, {
    String? sourceId,
    bool recursive = false,
  }) {
    final key = normalizeUri(uri);
    final prefix = key.endsWith('/') ? key : '$key/';
    final matchingUris = _diagnosticsByUri.keys
        .where(
          (candidate) =>
              candidate == key ||
              (recursive && candidate.startsWith(prefix)),
        )
        .toList();
    var changed = false;
    for (final matchingUri in matchingUris) {
      final sources = _diagnosticsByUri[matchingUri];
      if (sources == null) continue;
      if (sourceId == null) {
        _diagnosticsByUri.remove(matchingUri);
        changed = true;
      } else {
        changed = sources.remove(sourceId) != null || changed;
        if (sources.isEmpty) _diagnosticsByUri.remove(matchingUri);
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void clearForSource(String sourceId) {
    var changed = false;
    for (final entry in _diagnosticsByUri.entries.toList()) {
      changed = entry.value.remove(sourceId) != null || changed;
      if (entry.value.isEmpty) _diagnosticsByUri.remove(entry.key);
    }
    if (changed) notifyListeners();
  }

  /// مسح جميع المشاكل
  void clearAll() {
    if (_diagnosticsByUri.isEmpty) return;
    _diagnosticsByUri.clear();
    notifyListeners();
  }
}

class _DiagnosticSourceState {
  final List<DiagnosticItem> items;
  final int? latestVersion;

  const _DiagnosticSourceState({
    required this.items,
    required this.latestVersion,
  });
}
