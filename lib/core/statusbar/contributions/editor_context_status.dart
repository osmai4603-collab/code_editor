import 'package:flutter/material.dart';

import '../../../layout/controllers/editor_controller.dart';
import '../editor_status_controller.dart';
import '../models/status_bar_alignment.dart';
import '../models/status_bar_entry.dart';
import '../status_bar_service.dart';

class EditorContextStatusContribution {
  final EditorDocumentsController _documents;
  final EditorStatusController _editorStatus;
  final StatusBarService _statusBar;

  StatusBarEntryHandle? _fileEntry;
  StatusBarEntryHandle? _languageEntry;
  StatusBarEntryHandle? _cursorEntry;
  bool _isDisposed = false;

  EditorContextStatusContribution({
    required EditorDocumentsController documents,
    required EditorStatusController editorStatus,
    required StatusBarService statusBar,
  }) : _documents = documents,
       _editorStatus = editorStatus,
       _statusBar = statusBar {
    _documents.addListener(_update);
    _editorStatus.addListener(_update);
    _update();
  }

  void _update() {
    if (_isDisposed) return;
    final tab = _documents.activeTab;
    if (tab == null) {
      _fileEntry?.dispose();
      _languageEntry?.dispose();
      _cursorEntry?.dispose();
      _fileEntry = null;
      _languageEntry = null;
      _cursorEntry = null;
      return;
    }

    final dirtyLabel = tab.isDirty ? ' (unsaved changes)' : '';
    final fileEntry = StatusBarEntry(
      id: 'editor.file',
      name: 'Active file',
      text: '${tab.title}${tab.isDirty ? ' •' : ''}',
      alignment: StatusBarAlignment.right,
      priority: 300,
      tooltip: '${tab.path}$dirtyLabel',
      ariaLabel: '${tab.title}$dirtyLabel',
      icon: Icons.description_outlined,
    );
    if (_fileEntry == null) {
      _fileEntry = _statusBar.addEntry(fileEntry);
    } else {
      _fileEntry!.update(fileEntry);
    }

    final language = _languageName(tab.languageId);
    final languageEntry = StatusBarEntry(
      id: 'editor.language',
      name: 'Language mode',
      text: language,
      alignment: StatusBarAlignment.right,
      priority: 100,
      tooltip: 'Language mode: $language',
      ariaLabel: 'Language mode: $language',
      icon: Icons.code,
    );
    if (_languageEntry == null) {
      _languageEntry = _statusBar.addEntry(languageEntry);
    } else {
      _languageEntry!.update(languageEntry);
    }

    final snapshot = _editorStatus.snapshot;
    if (snapshot == null || snapshot.tabId != tab.id) {
      _cursorEntry?.dispose();
      _cursorEntry = null;
      return;
    }
    final cursorEntry = StatusBarEntry(
      id: 'editor.cursor',
      name: 'Cursor position',
      text: 'Ln ${snapshot.line}, Col ${snapshot.column}',
      alignment: StatusBarAlignment.right,
      priority: 500,
      tooltip: 'Line ${snapshot.line}, column ${snapshot.column}',
      ariaLabel: 'Line ${snapshot.line}, column ${snapshot.column}',
      icon: Icons.pin,
    );
    if (_cursorEntry == null) {
      _cursorEntry = _statusBar.addEntry(cursorEntry);
    } else {
      _cursorEntry!.update(cursorEntry);
    }
  }

  String _languageName(String languageId) {
    const knownNames = {
      'plaintext': 'Plain Text',
      'dart': 'Dart',
      'python': 'Python',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'json': 'JSON',
      'cpp': 'C++',
      'gdscript': 'GDScript',
    };
    final normalizedId = languageId.trim().toLowerCase();
    return knownNames[normalizedId] ??
        normalizedId
            .split(RegExp(r'[_\-\s]+'))
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _documents.removeListener(_update);
    _editorStatus.removeListener(_update);
    _fileEntry?.dispose();
    _languageEntry?.dispose();
    _cursorEntry?.dispose();
  }
}
