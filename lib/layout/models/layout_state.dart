import '../../core/constants/editor_constants.dart';

enum ActivityBarItem {
  explorer,
  search,
  sourceControl,
  runDebug,
  extensions,
  settings,
}

enum PanelTab {
  problems,
  output,
  terminal,
  debugConsole,
}

enum AuxiliaryBarTab {
  chat,
  outline,
}

/// حالة تخطيط نوافذ المحرر
class WorkbenchLayoutState {
  final ActivityBarItem activeActivity;
  final bool isSideBarVisible;
  final double sideBarWidth;

  final bool isAuxiliaryBarVisible;
  final AuxiliaryBarTab activeAuxiliaryTab;
  final double auxiliaryBarWidth;

  final bool isPanelVisible;
  final PanelTab activePanelTab;
  final double panelHeight;
  final bool isPanelMaximized;

  final bool isTitleBarVisible;
  final bool isStatusBarVisible;
  final bool isActivityBarVisible;
  final bool isZenMode;

  const WorkbenchLayoutState({
    this.activeActivity = ActivityBarItem.explorer,
    this.isSideBarVisible = true,
    this.sideBarWidth = EditorConstants.sideBarDefaultWidth,
    this.isAuxiliaryBarVisible = false,
    this.activeAuxiliaryTab = AuxiliaryBarTab.chat,
    this.auxiliaryBarWidth = EditorConstants.auxiliaryBarDefaultWidth,
    this.isPanelVisible = true,
    this.activePanelTab = PanelTab.terminal,
    this.panelHeight = EditorConstants.panelDefaultHeight,
    this.isPanelMaximized = false,
    this.isTitleBarVisible = true,
    this.isStatusBarVisible = true,
    this.isActivityBarVisible = true,
    this.isZenMode = false,
  });

  WorkbenchLayoutState copyWith({
    ActivityBarItem? activeActivity,
    bool? isSideBarVisible,
    double? sideBarWidth,
    bool? isAuxiliaryBarVisible,
    AuxiliaryBarTab? activeAuxiliaryTab,
    double? auxiliaryBarWidth,
    bool? isPanelVisible,
    PanelTab? activePanelTab,
    double? panelHeight,
    bool? isPanelMaximized,
    bool? isTitleBarVisible,
    bool? isStatusBarVisible,
    bool? isActivityBarVisible,
    bool? isZenMode,
  }) {
    return WorkbenchLayoutState(
      activeActivity: activeActivity ?? this.activeActivity,
      isSideBarVisible: isSideBarVisible ?? this.isSideBarVisible,
      sideBarWidth: sideBarWidth ?? this.sideBarWidth,
      isAuxiliaryBarVisible: isAuxiliaryBarVisible ?? this.isAuxiliaryBarVisible,
      activeAuxiliaryTab: activeAuxiliaryTab ?? this.activeAuxiliaryTab,
      auxiliaryBarWidth: auxiliaryBarWidth ?? this.auxiliaryBarWidth,
      isPanelVisible: isPanelVisible ?? this.isPanelVisible,
      activePanelTab: activePanelTab ?? this.activePanelTab,
      panelHeight: panelHeight ?? this.panelHeight,
      isPanelMaximized: isPanelMaximized ?? this.isPanelMaximized,
      isTitleBarVisible: isTitleBarVisible ?? this.isTitleBarVisible,
      isStatusBarVisible: isStatusBarVisible ?? this.isStatusBarVisible,
      isActivityBarVisible: isActivityBarVisible ?? this.isActivityBarVisible,
      isZenMode: isZenMode ?? this.isZenMode,
    );
  }
}
