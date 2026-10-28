import 'package:flutter/widgets.dart';

import 'app_theme_data.dart';

class AppTheme extends InheritedWidget {
  final AppThemeData theme;
  final Future<void> Function(AppThemeData theme) onThemeChanged;

  const AppTheme({
    super.key,
    required this.theme,
    required this.onThemeChanged,
    required super.child,
  });

  static AppTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTheme>();

  static AppThemeData of(BuildContext context) {
    final result = maybeOf(context);
    return result?.theme ?? AppThemeData.darkModern;
  }

  @override
  bool updateShouldNotify(AppTheme oldWidget) =>
      !identical(theme, oldWidget.theme);
}
