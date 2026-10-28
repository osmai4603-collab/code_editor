import 'package:code_editor/core/statusbar/models/status_bar_alignment.dart';
import 'package:code_editor/core/statusbar/models/status_bar_entry.dart';
import 'package:code_editor/core/statusbar/models/status_bar_entry_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entry keeps typed presentation and action data immutable', () {
    void action() {}
    const entry = StatusBarEntry(
      id: 'editor.language',
      name: 'Language mode',
      text: 'Dart',
      alignment: StatusBarAlignment.right,
      priority: 100,
      tooltip: 'Language mode: Dart',
      ariaLabel: 'Language mode: Dart',
      kind: StatusBarEntryKind.standard,
      icon: Icons.code,
    );

    final updated = entry.copyWith(
      text: 'Python',
      kind: StatusBarEntryKind.warning,
      onPressed: action,
    );

    expect(entry.text, 'Dart');
    expect(updated.id, entry.id);
    expect(updated.name, entry.name);
    expect(updated.text, 'Python');
    expect(updated.alignment, StatusBarAlignment.right);
    expect(updated.priority, 100);
    expect(updated.tooltip, 'Language mode: Dart');
    expect(updated.ariaLabel, 'Language mode: Dart');
    expect(updated.kind, StatusBarEntryKind.warning);
    expect(updated.icon, Icons.code);
    expect(updated.onPressed, same(action));
  });
}
