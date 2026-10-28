import 'package:code_editor/core/constants/editor_constants.dart';
import 'package:code_editor/layout/controllers/layout_controller.dart';
import 'package:code_editor/layout/models/layout_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkbenchLayoutController controller;

  setUp(() => controller = WorkbenchLayoutController());
  tearDown(() => controller.dispose());

  test('selecting a panel tab reveals the panel without changing its size', () {
    controller.resizePanel(-80);
    final resizedHeight = controller.state.panelHeight;
    controller.togglePanel();

    controller.selectPanelTab(PanelTab.problems);

    expect(controller.state.activePanelTab, PanelTab.problems);
    expect(controller.state.isPanelVisible, isTrue);
    expect(controller.state.panelHeight, resizedHeight);
  });

  test('panel resizing respects configured bounds and snap behavior', () {
    controller.resizePanel(-100000);
    expect(controller.state.panelHeight, EditorConstants.panelMaxHeight);

    controller.resizePanel(100000);
    expect(controller.state.isPanelVisible, isFalse);
    expect(controller.state.panelHeight, EditorConstants.panelMaxHeight);
  });

  test('maximizing and restoring the panel preserves its selected tab', () {
    controller.selectPanelTab(PanelTab.output);
    controller.togglePanelMaximized();
    expect(controller.state.isPanelMaximized, isTrue);

    controller.togglePanelMaximized();

    expect(controller.state.isPanelMaximized, isFalse);
    expect(controller.state.activePanelTab, PanelTab.output);
  });
}
