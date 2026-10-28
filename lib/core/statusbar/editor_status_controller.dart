import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class EditorStatusSnapshot {
  final String tabId;
  final int line;
  final int column;

  const EditorStatusSnapshot({
    required this.tabId,
    required this.line,
    required this.column,
  });
}

class EditorStatusController extends ChangeNotifier {
  EditorStatusSnapshot? _snapshot;

  EditorStatusSnapshot? get snapshot => _snapshot;

  void update(String tabId, String text, TextSelection selection) {
    final offset = selection.extentOffset.clamp(0, text.length);
    final prefix = text.substring(0, offset);
    final lineBreak = prefix.lastIndexOf('\n');
    final nextSnapshot = EditorStatusSnapshot(
      tabId: tabId,
      line: '\n'.allMatches(prefix).length + 1,
      column: prefix.length - lineBreak,
    );
    if (_snapshot?.tabId == nextSnapshot.tabId &&
        _snapshot?.line == nextSnapshot.line &&
        _snapshot?.column == nextSnapshot.column) {
      return;
    }
    _snapshot = nextSnapshot;
    notifyListeners();
  }

  void clearForTab(String tabId) {
    if (_snapshot?.tabId != tabId) return;
    _snapshot = null;
    notifyListeners();
  }
}
