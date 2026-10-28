import 'package:flutter/material.dart';
import '../../core/constants/editor_constants.dart';
import '../models/layout_state.dart';

/// وحدة التحكم المركزية بتخطيط واجهة المحرر
class WorkbenchLayoutController extends ChangeNotifier {
  WorkbenchLayoutState _state = const WorkbenchLayoutState();

  WorkbenchLayoutState get state => _state;

  void updateState(WorkbenchLayoutState Function(WorkbenchLayoutState) updater) {
    _state = updater(_state);
    notifyListeners();
  }

  /// تبديل أو تفعيل أيقونة شريط الأنشطة
  void selectActivity(ActivityBarItem item) {
    if (_state.activeActivity == item && _state.isSideBarVisible) {
      // إخفاء الشريط الجانبي إذا ضغط المطور على نفس الأيقونة المفتوحة
      _state = _state.copyWith(isSideBarVisible: false);
    } else {
      _state = _state.copyWith(
        activeActivity: item,
        isSideBarVisible: true,
      );
    }
    notifyListeners();
  }

  /// إظهار/إخفاء الشريط الجانبي الرئيسي
  void toggleSideBar() {
    _state = _state.copyWith(isSideBarVisible: !_state.isSideBarVisible);
    notifyListeners();
  }

  /// تغيير عرض الشريط الجانبي الرئيسي مع تطبيق القيود
  void resizeSideBar(double delta) {
    final newWidth = _state.sideBarWidth + delta;
    if (newWidth < EditorConstants.sideBarSnapThreshold) {
      _state = _state.copyWith(isSideBarVisible: false);
    } else {
      final clamped = newWidth.clamp(
        EditorConstants.sideBarMinWidth,
        EditorConstants.sideBarMaxWidth,
      );
      _state = _state.copyWith(
        sideBarWidth: clamped,
        isSideBarVisible: true,
      );
    }
    notifyListeners();
  }

  /// إظهار/إخفاء الشريط الإضافي (الأيمن)
  void toggleAuxiliaryBar() {
    _state = _state.copyWith(isAuxiliaryBarVisible: !_state.isAuxiliaryBarVisible);
    notifyListeners();
  }

  /// اختيار تبويب الشريط الإضافي
  void selectAuxiliaryTab(AuxiliaryBarTab tab) {
    _state = _state.copyWith(
      activeAuxiliaryTab: tab,
      isAuxiliaryBarVisible: true,
    );
    notifyListeners();
  }

  /// تغيير عرض الشريط الإضافي مع تطبيق القيود
  void resizeAuxiliaryBar(double delta) {
    final newWidth = _state.auxiliaryBarWidth - delta; // السحب من اليسار لليمين يقلص العرض
    if (newWidth < EditorConstants.auxiliaryBarSnapThreshold) {
      _state = _state.copyWith(isAuxiliaryBarVisible: false);
    } else {
      final clamped = newWidth.clamp(
        EditorConstants.auxiliaryBarMinWidth,
        EditorConstants.auxiliaryBarMaxWidth,
      );
      _state = _state.copyWith(
        auxiliaryBarWidth: clamped,
        isAuxiliaryBarVisible: true,
      );
    }
    notifyListeners();
  }

  /// إظهار/إخفاء اللوحة السفلية
  void togglePanel() {
    _state = _state.copyWith(isPanelVisible: !_state.isPanelVisible);
    notifyListeners();
  }

  /// تكبير اللوحة السفلية لأقصى حجم أو استعادتها
  void togglePanelMaximized() {
    _state = _state.copyWith(isPanelMaximized: !_state.isPanelMaximized);
    notifyListeners();
  }

  /// اختيار تبويب اللوحة السفلية
  void selectPanelTab(PanelTab tab) {
    _state = _state.copyWith(
      activePanelTab: tab,
      isPanelVisible: true,
    );
    notifyListeners();
  }

  /// تغيير ارتفاع اللوحة السفلية بالسحب
  void resizePanel(double delta) {
    final newHeight = _state.panelHeight - delta; // السحب للأعلى يزيد الارتفاع
    if (newHeight < EditorConstants.panelSnapThreshold) {
      _state = _state.copyWith(isPanelVisible: false);
    } else {
      final clamped = newHeight.clamp(
        EditorConstants.panelMinHeight,
        EditorConstants.panelMaxHeight,
      );
      _state = _state.copyWith(
        panelHeight: clamped,
        isPanelVisible: true,
      );
    }
    notifyListeners();
  }

  /// تبديل وضع التركيز التام (Zen Mode)
  void toggleZenMode() {
    final nextZen = !_state.isZenMode;
    _state = _state.copyWith(
      isZenMode: nextZen,
      isSideBarVisible: !nextZen,
      isActivityBarVisible: !nextZen,
      isPanelVisible: !nextZen,
      isAuxiliaryBarVisible: false,
      isStatusBarVisible: !nextZen,
    );
    notifyListeners();
  }
}

/// InheritedNotifier لمشاركة الـ Controller في الشجرة بكفاءة
class WorkbenchLayoutScope extends InheritedNotifier<WorkbenchLayoutController> {
  const WorkbenchLayoutScope({
    super.key,
    required WorkbenchLayoutController super.notifier,
    required super.child,
  });

  static WorkbenchLayoutController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WorkbenchLayoutScope>();
    assert(scope != null, 'WorkbenchLayoutScope not found in context');
    return scope!.notifier!;
  }
}
