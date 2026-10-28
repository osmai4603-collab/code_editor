import 'package:flutter/material.dart';

import 'editor_formatting_preferences.dart';

class EditorFormattingPreferencesScope
    extends InheritedNotifier<EditorFormattingPreferencesController> {
  const EditorFormattingPreferencesScope({
    super.key,
    required EditorFormattingPreferencesController super.notifier,
    required super.child,
  });

  static EditorFormattingPreferencesController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EditorFormattingPreferencesScope>();
    assert(scope != null, 'EditorFormattingPreferencesScope not found');
    return scope!.notifier!;
  }
}
