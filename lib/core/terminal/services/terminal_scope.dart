import 'package:flutter/material.dart';
import 'terminal_service.dart';

class TerminalScope extends InheritedNotifier<TerminalService> {
  const TerminalScope({
    super.key,
    required TerminalService super.notifier,
    required super.child,
  });

  static TerminalService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TerminalScope>();
    assert(scope != null, 'TerminalScope not found in context');
    return scope!.notifier!;
  }
}
