import 'package:flutter/widgets.dart';

import '../services/configuration_service.dart';

class ConfigurationScope extends InheritedNotifier<ConfigurationService> {
  const ConfigurationScope({
    super.key,
    required ConfigurationService super.notifier,
    required super.child,
  });

  static ConfigurationService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ConfigurationScope>();
    assert(scope != null, 'ConfigurationScope not found');
    return scope!.notifier!;
  }
}
