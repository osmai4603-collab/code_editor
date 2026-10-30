import 'package:code_editor/core/statusbar/models/status_bar_alignment.dart';
import 'package:code_editor/core/statusbar/models/status_bar_entry.dart';
import 'package:code_editor/core/statusbar/status_bar_preferences_store.dart';
import 'package:code_editor/core/statusbar/status_bar_scope.dart';
import 'package:code_editor/core/statusbar/status_bar_service.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/layout/controllers/layout_controller.dart';
import 'package:code_editor/parts/statusbar/statusbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StatusBarService statusBar;
  late WorkbenchLayoutController layout;

  setUp(() async {
    statusBar = StatusBarService(
      preferencesStore: InMemoryStatusBarPreferencesStore(),
    );
    await statusBar.initialize();
    layout = WorkbenchLayoutController();
  });

  tearDown(() {
    statusBar.dispose();
    layout.dispose();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: EditorTheme(
        theme: EditorThemeData.darkModern,
        child: StatusBarScope(
          notifier: statusBar,
          child: WorkbenchLayoutScope(
            notifier: layout,
            child: const Scaffold(body: StatusBarWidget()),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renders ordered left and right entries and retains 22px height',
    (tester) async {
      statusBar
        ..addEntry(
          const StatusBarEntry(
            id: 'left-low',
            name: 'Left Low',
            text: 'left-low',
            alignment: StatusBarAlignment.left,
            priority: 1,
          ),
        )
        ..addEntry(
          const StatusBarEntry(
            id: 'left-high',
            name: 'Left High',
            text: 'left-high',
            alignment: StatusBarAlignment.left,
            priority: 10,
          ),
        )
        ..addEntry(
          const StatusBarEntry(
            id: 'right',
            name: 'Right',
            text: 'right',
            alignment: StatusBarAlignment.right,
            priority: 1,
          ),
        );

      await tester.pumpWidget(buildSubject());

      final highX = tester.getTopLeft(find.text('left-high')).dx;
      final lowX = tester.getTopLeft(find.text('left-low')).dx;
      final rightX = tester.getTopLeft(find.text('right')).dx;
      expect(highX, lessThan(lowX));
      expect(rightX, greaterThan(lowX));
      expect(tester.getSize(find.byType(StatusBarWidget)).height, 22);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('defers status updates triggered while the tree is building', (
    tester,
  ) async {
    var didAddEntry = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EditorTheme(
          theme: EditorThemeData.darkModern,
          child: StatusBarScope(
            notifier: statusBar,
            child: Builder(
              builder: (context) {
                if (!didAddEntry) {
                  didAddEntry = true;
                  statusBar.addEntry(
                    const StatusBarEntry(
                      id: 'during-build',
                      name: 'During build',
                      text: 'ready',
                      alignment: StatusBarAlignment.left,
                      priority: 0,
                    ),
                  );
                }
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(statusBar.entries.any((entry) => entry.id == 'during-build'), isTrue);
  });

  testWidgets('does not expose a passive status as a button', (tester) async {
    statusBar.addEntry(
      const StatusBarEntry(
        id: 'passive',
        name: 'Passive status',
        text: 'Saved',
        alignment: StatusBarAlignment.left,
        priority: 0,
        ariaLabel: 'Document saved',
      ),
    );

    await tester.pumpWidget(buildSubject());

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Document saved',
      ),
    );
    expect(semantics.properties.button, isFalse);
  });

  testWidgets('management menu hides and restores individual entries', (
    tester,
  ) async {
    statusBar.addEntry(
      const StatusBarEntry(
        id: 'toggle-item',
        name: 'Toggle item',
        text: 'Visible item',
        alignment: StatusBarAlignment.left,
        priority: 0,
      ),
    );
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byTooltip('Manage Status Bar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle item').last);
    await tester.pumpAndSettle();
    await tester.pump();
    expect(statusBar.isEntryVisible('toggle-item'), isFalse);
    expect(find.text('Visible item'), findsNothing);

    await tester.tap(find.byTooltip('Manage Status Bar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle item'));
    await tester.pumpAndSettle();
    expect(find.text('Visible item'), findsOneWidget);

    await tester.tap(find.byTooltip('Manage Status Bar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide Status Bar'));
    await tester.pumpAndSettle();
    expect(layout.state.isStatusBarVisible, isFalse);
  });

  testWidgets('handles a narrow width and long labels without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(170, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    for (var index = 0; index < 8; index++) {
      statusBar.addEntry(
        StatusBarEntry(
          id: 'long-$index',
          name: 'Entry $index',
          text: 'a very long status item value $index',
          alignment: index.isEven
              ? StatusBarAlignment.left
              : StatusBarAlignment.right,
          priority: index,
        ),
      );
    }

    await tester.pumpWidget(buildSubject());

    expect(tester.takeException(), isNull);
  });

  test('status bar visibility remains independent of Zen Mode', () {
    layout.toggleStatusBar();
    expect(layout.state.isStatusBarVisible, isFalse);

    layout.toggleZenMode();
    expect(layout.state.isZenMode, isTrue);
    expect(layout.state.isStatusBarVisible, isFalse);

    layout.toggleZenMode();
    expect(layout.state.isZenMode, isFalse);
    expect(layout.state.isStatusBarVisible, isFalse);

    layout.toggleStatusBar();
    layout.toggleZenMode();
    expect(layout.state.isStatusBarVisible, isTrue);
    layout.toggleZenMode();
    expect(layout.state.isStatusBarVisible, isTrue);
  });
}
