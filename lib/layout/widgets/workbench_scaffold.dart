import 'package:flutter/material.dart';
import '../../core/constants/editor_constants.dart';
import '../../core/theme/editor_theme.dart';
import '../../parts/activitybar/activitybar_widget.dart';
import '../../parts/auxiliarybar/auxiliarybar_widget.dart';
import '../../parts/editor/editor_area_widget.dart';
import '../../parts/panel/panel_widget.dart';
import '../../parts/sidebar/sidebar_widget.dart';
import '../../parts/statusbar/statusbar_widget.dart';
import '../../parts/titlebar/titlebar_widget.dart';
import '../controllers/layout_controller.dart';
import 'resizable_splitter.dart';

/// الشاشة الرئيسية المجمعة لشبكة واجهة المحرر (Workbench Scaffold)
class WorkbenchScaffold extends StatelessWidget {
  const WorkbenchScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final layoutController = WorkbenchLayoutScope.of(context);
    final state = layoutController.state;

    return Scaffold(
      backgroundColor: theme.editorBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. شريط العنوان العلوي (TitleBar)
            if (state.isTitleBarVisible && !state.isZenMode)
              const TitleBarWidget(),

            // 2. القسم الأوسط الرئيسي (Middle Section: ActivityBar, SideBar, Editor, Panel, AuxiliaryBar)
            Expanded(
              child: Row(
                children: [
                  // شريط الأنشطة الرأسي الأيسر
                  if (state.isActivityBarVisible && !state.isZenMode)
                    const ActivityBarWidget(),

                  // الشريط الجانبي الرئيسي (Explorer / Search ...)
                  if (state.isSideBarVisible && !state.isZenMode) ...[
                    SizedBox(
                      width: state.sideBarWidth,
                      child: const SideBarWidget(),
                    ),
                    ResizableSplitter(
                      orientation: SplitterOrientation.horizontal,
                      onDragDelta: layoutController.resizeSideBar,
                      onDoubleTap: layoutController.toggleSideBar,
                    ),
                  ],

                  // المنطقة المركزية (Editor Area + Bottom Panel)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final minimumEditorHeight =
                            EditorConstants.tabHeight +
                            EditorConstants.breadcrumbsHeight;
                        final maxPanelHeight =
                            (constraints.maxHeight -
                                    EditorConstants.sashThickness -
                                    minimumEditorHeight)
                                .clamp(0.0, double.infinity);
                        final panelHeight = state.panelHeight
                            .clamp(0.0, maxPanelHeight)
                            .toDouble();

                        return Column(
                          children: [
                            // مساحة التحرير (تختفي إذا كانت اللوحة السفلية في وضع التكبير التام Maximize)
                            if (!state.isPanelMaximized ||
                                !state.isPanelVisible)
                              const Expanded(child: EditorAreaWidget()),

                            // اللوحة السفلية (Terminal / Problems / Output)
                            if (state.isPanelVisible && !state.isZenMode) ...[
                              if (state.isPanelMaximized)
                                const Expanded(child: PanelWidget())
                              else ...[
                                ResizableSplitter(
                                  orientation: SplitterOrientation.vertical,
                                  onDragDelta: layoutController.resizePanel,
                                  onDoubleTap:
                                      layoutController.togglePanelMaximized,
                                ),
                                SizedBox(
                                  height: panelHeight,
                                  child: const PanelWidget(),
                                ),
                              ],
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                  // الشريط الجانبي الإضافي / الأيمن (AI Chat / Outline)
                  if (state.isAuxiliaryBarVisible && !state.isZenMode) ...[
                    ResizableSplitter(
                      orientation: SplitterOrientation.horizontal,
                      onDragDelta: layoutController.resizeAuxiliaryBar,
                      onDoubleTap: layoutController.toggleAuxiliaryBar,
                    ),
                    SizedBox(
                      width: state.auxiliaryBarWidth,
                      child: const AuxiliaryBarWidget(),
                    ),
                  ],
                ],
              ),
            ),

            // 3. شريط الحالة السفلي (StatusBar)
            if (state.isStatusBarVisible && !state.isZenMode)
              const StatusBarWidget(),
          ],
        ),
      ),
    );
  }
}
