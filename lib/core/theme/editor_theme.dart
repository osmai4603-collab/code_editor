import 'package:flutter/material.dart';
import '../lsp/protocol/lsp_types.dart';

/// نظام السمات والألوان المخصص لمحرر الأكواد
/// مستوحى من نظام تصميم VS Code Dark+ Modern
class EditorThemeData {
  final Color titleBarBackground;
  final Color titleBarForeground;
  final Color titleBarBorder;
  final Color activityBarBackground;
  final Color activityBarForeground;
  final Color activityBarActiveBorder;
  final Color activityBarBadge;
  final Color sideBarBackground;
  final Color sideBarForeground;
  final Color sideBarTitleForeground;
  final Color sideBarBorder;
  final Color editorBackground;
  final Color editorForeground;
  final Color editorGutterBackground;
  final Color editorLineNumber;
  final Color editorLineNumberActive;
  final Color editorCurrentLineHighlight;
  final Color editorSelection;
  final Color editorScrollbarTrack;
  final Color editorScrollbarThumb;
  final Color editorScrollbarThumbHover;
  final Color editorScrollbarThumbActive;
  final Color diagnosticError;
  final Color diagnosticWarning;
  final Color diagnosticInformation;
  final Color diagnosticHint;
  final Color tabActiveBackground;
  final Color tabActiveForeground;
  final Color tabActiveBorderTop;
  final Color tabInactiveBackground;
  final Color tabInactiveForeground;
  final Color tabBorder;
  final Color panelBackground;
  final Color panelForeground;
  final Color panelBorder;
  final Color panelTitleActive;
  final Color panelTitleInactive;
  final Color statusBarBackground;
  final Color statusBarForeground;
  final Color statusBarItemHover;
  final Color statusBarItemFocus;
  final Color statusBarWarningForeground;
  final Color statusBarWarningBackground;
  final Color statusBarErrorForeground;
  final Color statusBarErrorBackground;
  final Color auxiliaryBarBackground;
  final Color auxiliaryBarBorder;
  final Color sashHover;
  final Color sashActive;
  final Color commandCenterBackground;
  final Color commandCenterBorder;
  final Color commandCenterForeground;
  final Color accentColor;
  final Color terminalBackground;
  final Color terminalForeground;
  final Color terminalCursor;
  final Color terminalSelectionBackground;
  final List<Color> terminalAnsiColors;

  const EditorThemeData({
    required this.titleBarBackground,
    required this.titleBarForeground,
    required this.titleBarBorder,
    required this.activityBarBackground,
    required this.activityBarForeground,
    required this.activityBarActiveBorder,
    required this.activityBarBadge,
    required this.sideBarBackground,
    required this.sideBarForeground,
    required this.sideBarTitleForeground,
    required this.sideBarBorder,
    required this.editorBackground,
    required this.editorForeground,
    required this.editorGutterBackground,
    required this.editorLineNumber,
    required this.editorLineNumberActive,
    required this.editorCurrentLineHighlight,
    required this.editorSelection,
    required this.editorScrollbarTrack,
    required this.editorScrollbarThumb,
    required this.editorScrollbarThumbHover,
    required this.editorScrollbarThumbActive,
    required this.diagnosticError,
    required this.diagnosticWarning,
    required this.diagnosticInformation,
    required this.diagnosticHint,
    required this.tabActiveBackground,
    required this.tabActiveForeground,
    required this.tabActiveBorderTop,
    required this.tabInactiveBackground,
    required this.tabInactiveForeground,
    required this.tabBorder,
    required this.panelBackground,
    required this.panelForeground,
    required this.panelBorder,
    required this.panelTitleActive,
    required this.panelTitleInactive,
    required this.statusBarBackground,
    required this.statusBarForeground,
    required this.statusBarItemHover,
    required this.statusBarItemFocus,
    required this.statusBarWarningForeground,
    required this.statusBarWarningBackground,
    required this.statusBarErrorForeground,
    required this.statusBarErrorBackground,
    required this.auxiliaryBarBackground,
    required this.auxiliaryBarBorder,
    required this.sashHover,
    required this.sashActive,
    required this.commandCenterBackground,
    required this.commandCenterBorder,
    required this.commandCenterForeground,
    required this.accentColor,
    required this.terminalBackground,
    required this.terminalForeground,
    required this.terminalCursor,
    required this.terminalSelectionBackground,
    required this.terminalAnsiColors,
  });

  /// الثيم الداكن الافتراضي (Dark Modern)
  static const darkModern = EditorThemeData(
    titleBarBackground: Color(0xFF181818),
    titleBarForeground: Color(0xFFCCCCCC),
    titleBarBorder: Color(0xFF2B2B2B),
    activityBarBackground: Color(0xFF181818),
    activityBarForeground: Color(0xFF858585),
    activityBarActiveBorder: Color(0xFF0078D4),
    activityBarBadge: Color(0xFF0078D4),
    sideBarBackground: Color(0xFF1E1E1E),
    sideBarForeground: Color(0xFFCCCCCC),
    sideBarTitleForeground: Color(0xFFBBBBBB),
    sideBarBorder: Color(0xFF2B2B2B),
    editorBackground: Color(0xFF1F1F1F),
    editorForeground: Color(0xFFD4D4D4),
    editorGutterBackground: Color(0xFF1F1F1F),
    editorLineNumber: Color(0xFF6E7681),
    editorLineNumberActive: Color(0xFFCCCCCC),
    editorCurrentLineHighlight: Color(0x1AFFFFFF),
    editorSelection: Color(0x33264F78),
    editorScrollbarTrack: Color(0x337F7F7F),
    editorScrollbarThumb: Color(0x997F7F7F),
    editorScrollbarThumbHover: Color(0xCC9E9E9E),
    editorScrollbarThumbActive: Color(0xFF0078D4),
    diagnosticError: Color(0xFFF14C4C),
    diagnosticWarning: Color(0xFFFFD580),
    diagnosticInformation: Color(0xFF3794FF),
    diagnosticHint: Color(0xFFB180D7),
    tabActiveBackground: Color(0xFF1F1F1F),
    tabActiveForeground: Color(0xFFFFFFFF),
    tabActiveBorderTop: Color(0xFF0078D4),
    tabInactiveBackground: Color(0xFF181818),
    tabInactiveForeground: Color(0xFF969696),
    tabBorder: Color(0xFF2B2B2B),
    panelBackground: Color(0xFF181818),
    panelForeground: Color(0xFFCCCCCC),
    panelBorder: Color(0xFF2B2B2B),
    panelTitleActive: Color(0xFFFFFFFF),
    panelTitleInactive: Color(0xFF858585),
    statusBarBackground: Color(0xFF181818),
    statusBarForeground: Color(0xFFCCCCCC),
    statusBarItemHover: Color(0x1AFFFFFF),
    statusBarItemFocus: Color(0xFFFFFFFF),
    statusBarWarningForeground: Color(0xFFFFD580),
    statusBarWarningBackground: Color(0xFF5A4300),
    statusBarErrorForeground: Color(0xFFFFB4AB),
    statusBarErrorBackground: Color(0xFF5C1F1A),
    auxiliaryBarBackground: Color(0xFF1E1E1E),
    auxiliaryBarBorder: Color(0xFF2B2B2B),
    sashHover: Color(0xFF0078D4),
    sashActive: Color(0xFF0078D4),
    commandCenterBackground: Color(0xFF252526),
    commandCenterBorder: Color(0xFF383838),
    commandCenterForeground: Color(0xFFCCCCCC),
    accentColor: Color(0xFF0078D4),
    terminalBackground: Color(0xFF1E1E1E),
    terminalForeground: Color(0xFFD4D4D4),
    terminalCursor: Color(0xFFAEAFAD),
    terminalSelectionBackground: Color(0xFF264F78),
    terminalAnsiColors: [
      Color(0xFF000000),
      Color(0xFFCD3131),
      Color(0xFF0DBC79),
      Color(0xFFE5E510),
      Color(0xFF2472C8),
      Color(0xFFBC3FBC),
      Color(0xFF11A8CD),
      Color(0xFFE5E5E5),
      Color(0xFF666666),
      Color(0xFFF14C4C),
      Color(0xFF23D18B),
      Color(0xFFF5F543),
      Color(0xFF3B8EEA),
      Color(0xFFD670D6),
      Color(0xFF29B8DB),
      Color(0xFFFFFFFF),
    ],
  );

  Color diagnosticColor(DiagnosticSeverity severity) => switch (severity) {
    DiagnosticSeverity.error => diagnosticError,
    DiagnosticSeverity.warning => diagnosticWarning,
    DiagnosticSeverity.information => diagnosticInformation,
    DiagnosticSeverity.hint => diagnosticHint,
  };
}

/// InheritedWidget لتوفير ثيم المحرر في كامل شجرة الودجات
class EditorTheme extends InheritedWidget {
  final EditorThemeData theme;

  const EditorTheme({
    super.key,
    required this.theme,
    required super.child,
  });

  static EditorThemeData of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<EditorTheme>();
    return result?.theme ?? EditorThemeData.darkModern;
  }

  @override
  bool updateShouldNotify(EditorTheme oldWidget) => theme != oldWidget.theme;
}
