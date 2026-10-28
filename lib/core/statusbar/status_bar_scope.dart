import 'package:flutter/material.dart';

import 'editor_status_controller.dart';
import 'status_bar_service.dart';

class StatusBarScope extends InheritedNotifier<StatusBarService> {
  const StatusBarScope({
    super.key,
    required StatusBarService super.notifier,
    required super.child,
  });

  static StatusBarService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StatusBarScope>();
    assert(scope != null, 'StatusBarScope not found in context');
    return scope!.notifier!;
  }
}

class EditorStatusScope extends InheritedNotifier<EditorStatusController> {
  const EditorStatusScope({
    super.key,
    required EditorStatusController super.notifier,
    required super.child,
  });

  static EditorStatusController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EditorStatusScope>();
    assert(scope != null, 'EditorStatusScope not found in context');
    return scope!.notifier!;
  }
}
