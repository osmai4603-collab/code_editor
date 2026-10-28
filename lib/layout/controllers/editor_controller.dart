import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/editor_tab_item.dart';

/// وحدة التحكم بإدارة التبويبات والمستندات المفتوحة في المحرر
class EditorDocumentsController extends ChangeNotifier {
  final List<EditorTabItem> _tabs = [];
  int _activeTabIndex = -1;

  List<EditorTabItem> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;

  EditorTabItem? get activeTab =>
      (_activeTabIndex >= 0 && _activeTabIndex < _tabs.length)
      ? _tabs[_activeTabIndex]
      : null;

  EditorDocumentsController();

  void openFile({
    required String title,
    required String path,
    required String content,
    String languageId = 'plaintext',
    bool isPreview = false,
  }) {
    final existingIndex = _tabs.indexWhere((t) => t.path == path);
    if (existingIndex != -1) {
      if (!isPreview && _tabs[existingIndex].isPreview) {
        _tabs[existingIndex] = _tabs[existingIndex].copyWith(isPreview: false);
      }
      _activeTabIndex = existingIndex;
    } else {
      final active = activeTab;
      if (active?.isPreview == true && active!.isDirty) {
        final activeIndex = _tabs.indexWhere((tab) => tab.id == active.id);
        _tabs[activeIndex] = active.copyWith(isPreview: false);
      }
      if (isPreview) {
        final previewIndex = _tabs.indexWhere(
          (tab) => tab.isPreview && !tab.isDirty,
        );
        if (previewIndex != -1) {
          _tabs.removeAt(previewIndex);
          if (_activeTabIndex > previewIndex) _activeTabIndex--;
        }
      }
      final newTab = EditorTabItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        path: path,
        content: content,
        languageId: languageId,
        isPreview: isPreview,
      );
      _tabs.add(newTab);
      _activeTabIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  void pinTab(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index == -1 || !_tabs[index].isPreview) return;
    _tabs[index] = _tabs[index].copyWith(isPreview: false);
    notifyListeners();
  }

  void selectTab(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1 && index != _activeTabIndex) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void closeTab(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tabs.removeAt(index);
      if (_tabs.isEmpty) {
        _activeTabIndex = -1;
      } else if (_activeTabIndex > index) {
        _activeTabIndex--;
      } else if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      notifyListeners();
    }
  }

  void updateContent(String id, String newContent) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tabs[index] = _tabs[index].copyWith(content: newContent, isDirty: true);
      notifyListeners();
    }
  }

  Future<void> saveCurrentTab() async {
    final tab = activeTab;
    if (tab != null) await saveTab(tab.id);
  }

  Future<void> saveTab(String id) async {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index == -1) return;
    final tab = _tabs[index];
    if (!tab.isDirty) return;
    await File(tab.path).writeAsString(tab.content);
    final currentIndex = _tabs.indexWhere((entry) => entry.id == id);
    if (currentIndex != -1 && _tabs[currentIndex].content == tab.content) {
      _tabs[currentIndex] = _tabs[currentIndex].copyWith(isDirty: false);
      notifyListeners();
    }
  }

  void updatePaths(String oldPath, String newPath) {
    var changed = false;
    for (var index = 0; index < _tabs.length; index++) {
      final tab = _tabs[index];
      if (tab.path == oldPath ||
          tab.path.startsWith('$oldPath${Platform.pathSeparator}')) {
        final path = '$newPath${tab.path.substring(oldPath.length)}';
        final title = path.split(Platform.pathSeparator).last;
        _tabs[index] = tab.copyWith(path: path, title: title);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void closePaths(List<String> paths) {
    final before = _tabs.length;
    final activeId = activeTab?.id;
    final activeIndexBefore = _activeTabIndex;
    _tabs.removeWhere(
      (tab) => paths.any(
        (path) =>
            tab.path == path ||
            tab.path.startsWith('$path${Platform.pathSeparator}'),
      ),
    );
    if (_tabs.length == before) return;
    if (_tabs.isEmpty) {
      _activeTabIndex = -1;
    } else {
      final retainedActiveIndex = _tabs.indexWhere((tab) => tab.id == activeId);
      _activeTabIndex = retainedActiveIndex >= 0
          ? retainedActiveIndex
          : activeIndexBefore.clamp(0, _tabs.length - 1).toInt();
    }
    notifyListeners();
  }
}

class EditorDocumentsScope
    extends InheritedNotifier<EditorDocumentsController> {
  const EditorDocumentsScope({
    super.key,
    required EditorDocumentsController super.notifier,
    required super.child,
  });

  static EditorDocumentsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EditorDocumentsScope>();
    assert(scope != null, 'EditorDocumentsScope not found in context');
    return scope!.notifier!;
  }
}
