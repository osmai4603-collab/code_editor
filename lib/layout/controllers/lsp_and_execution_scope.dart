import 'package:flutter/material.dart';
import '../../core/execution/execution_controller.dart';
import '../../core/lsp/diagnostics/diagnostics_service.dart';
import '../../core/lsp/registry/lsp_server_registry.dart';

/// نطاق توفير خدمة التشخيصات المركزية (DiagnosticsScope)
class DiagnosticsScope extends InheritedNotifier<DiagnosticsService> {
  const DiagnosticsScope({
    super.key,
    required DiagnosticsService super.notifier,
    required super.child,
  });

  static DiagnosticsService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DiagnosticsScope>();
    assert(scope != null, 'DiagnosticsScope not found in context');
    return scope!.notifier!;
  }
}

/// نطاق توفير متحكم تنفيذ الأكواد (ExecutionScope)
class ExecutionScope extends InheritedNotifier<ExecutionController> {
  const ExecutionScope({
    super.key,
    required ExecutionController super.notifier,
    required super.child,
  });

  static ExecutionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ExecutionScope>();
    assert(scope != null, 'ExecutionScope not found in context');
    return scope!.notifier!;
  }
}

/// نطاق توفير السجل المركزي لخوادم اللغات (LspRegistryScope)
class LspRegistryScope extends InheritedWidget {
  final LspServerRegistry registry;

  const LspRegistryScope({
    super.key,
    required this.registry,
    required super.child,
  });

  static LspServerRegistry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LspRegistryScope>();
    assert(scope != null, 'LspRegistryScope not found in context');
    return scope!.registry;
  }

  @override
  bool updateShouldNotify(covariant LspRegistryScope oldWidget) =>
      registry != oldWidget.registry;
}
