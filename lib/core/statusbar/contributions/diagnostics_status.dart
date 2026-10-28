import 'package:flutter/material.dart';

import '../../../layout/controllers/layout_controller.dart';
import '../../../layout/models/layout_state.dart';
import '../../lsp/diagnostics/diagnostics_service.dart';
import '../models/status_bar_alignment.dart';
import '../models/status_bar_entry.dart';
import '../models/status_bar_entry_kind.dart';
import '../status_bar_service.dart';

class DiagnosticsStatusContribution {
  final DiagnosticsService _diagnostics;
  final WorkbenchLayoutController _layout;
  final StatusBarService _statusBar;

  StatusBarEntryHandle? _errorsEntry;
  StatusBarEntryHandle? _warningsEntry;
  bool _isDisposed = false;

  DiagnosticsStatusContribution({
    required DiagnosticsService diagnostics,
    required WorkbenchLayoutController layout,
    required StatusBarService statusBar,
  }) : _diagnostics = diagnostics,
       _layout = layout,
       _statusBar = statusBar {
    _diagnostics.addListener(_update);
    _update();
  }

  void _update() {
    if (_isDisposed) return;
    final errors = _diagnostics.totalErrors;
    final warnings = _diagnostics.totalWarnings;
    if (errors == 0) {
      _errorsEntry?.dispose();
      _errorsEntry = null;
    } else {
      final entry = StatusBarEntry(
        id: 'diagnostics.errors',
        name: 'Errors',
        text: '$errors',
        alignment: StatusBarAlignment.left,
        priority: 1000,
        tooltip: '$errors ${errors == 1 ? 'error' : 'errors'}',
        ariaLabel: '$errors ${errors == 1 ? 'error' : 'errors'}',
        kind: StatusBarEntryKind.error,
        icon: Icons.error_outline,
        onPressed: _showProblems,
      );
      if (_errorsEntry == null) {
        _errorsEntry = _statusBar.addEntry(entry);
      } else {
        _errorsEntry!.update(entry);
      }
    }

    if (warnings == 0) {
      _warningsEntry?.dispose();
      _warningsEntry = null;
    } else {
      final entry = StatusBarEntry(
        id: 'diagnostics.warnings',
        name: 'Warnings',
        text: '$warnings',
        alignment: StatusBarAlignment.left,
        priority: 900,
        tooltip: '$warnings ${warnings == 1 ? 'warning' : 'warnings'}',
        ariaLabel: '$warnings ${warnings == 1 ? 'warning' : 'warnings'}',
        kind: StatusBarEntryKind.warning,
        icon: Icons.warning_amber_rounded,
        onPressed: _showProblems,
      );
      if (_warningsEntry == null) {
        _warningsEntry = _statusBar.addEntry(entry);
      } else {
        _warningsEntry!.update(entry);
      }
    }
  }

  void _showProblems() => _layout.selectPanelTab(PanelTab.problems);

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _diagnostics.removeListener(_update);
    _errorsEntry?.dispose();
    _warningsEntry?.dispose();
  }
}
