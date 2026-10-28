import 'package:flutter/foundation.dart';
import '../protocol/lsp_types.dart';

/// خدمة إدارة المشاكل والتشخيصات المركزية (Diagnostics Service)
///
/// تجمع الأخطاء والتحذيرات الواردة من خوادم LSP المتعددة،
/// وتخطر واجهة المستخدم (لوحة Problems وشريط الحالة والمحرر) بالتحديثات.
class DiagnosticsService extends ChangeNotifier {
  final Map<String, List<DiagnosticItem>> _diagnosticsByUri = {};

  /// الحصول على قائمة المشاكل لملف محدد
  List<DiagnosticItem> getForUri(String uri) {
    return _diagnosticsByUri[uri] ?? const [];
  }

  /// جميع المشاكل في مساحة العمل مجمعة
  List<DiagnosticItem> get allDiagnostics {
    final list = <DiagnosticItem>[];
    for (final items in _diagnosticsByUri.values) {
      list.addAll(items);
    }
    return list;
  }

  /// خريطة الملفات التي تحتوي على مشاكل
  Map<String, List<DiagnosticItem>> get diagnosticsByUri =>
      Map.unmodifiable(_diagnosticsByUri);

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
    if (items.isEmpty) {
      _diagnosticsByUri.remove(uri);
    } else {
      _diagnosticsByUri[uri] = List.unmodifiable(items);
    }
    notifyListeners();
  }

  /// مسح مشاكل ملف تم إغلاقه أو حذفه
  void clearForUri(String uri) {
    if (_diagnosticsByUri.containsKey(uri)) {
      _diagnosticsByUri.remove(uri);
      notifyListeners();
    }
  }

  /// مسح جميع المشاكل
  void clearAll() {
    _diagnosticsByUri.clear();
    notifyListeners();
  }
}
