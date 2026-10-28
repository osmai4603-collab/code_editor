import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/parts/editor/scrollbar/editor_scrollbar.dart';
import 'package:code_editor/parts/editor/scrollbar/editor_scrollbar_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorScrollbarThumbGeometry', () {
    test('uses the full track when there is no scroll range', () {
      final geometry = EditorScrollbarThumbGeometry.calculate(
        viewportExtent: 100,
        maxScrollExtent: 0,
        scrollOffset: 0,
        trackExtent: 80,
      );

      expect(geometry, isNotNull);
      expect(geometry!.thumbExtent, 80);
      expect(geometry.thumbOffset, 0);
    });

    test('maps the first and last scroll positions to track endpoints', () {
      final atStart = EditorScrollbarThumbGeometry.calculate(
        viewportExtent: 100,
        maxScrollExtent: 300,
        scrollOffset: 0,
        trackExtent: 100,
      )!;
      final atEnd = EditorScrollbarThumbGeometry.calculate(
        viewportExtent: 100,
        maxScrollExtent: 300,
        scrollOffset: 300,
        trackExtent: 100,
      )!;

      expect(atStart.thumbExtent, 25);
      expect(atStart.thumbOffset, 0);
      expect(atEnd.thumbOffset + atEnd.thumbExtent, 100);
      expect(atEnd.scrollOffsetForThumbOffset(75), 300);
    });

    test('clamps invalid offsets and enforces a minimum thumb size', () {
      final geometry = EditorScrollbarThumbGeometry.calculate(
        viewportExtent: 1,
        maxScrollExtent: 10000,
        scrollOffset: 12000,
        trackExtent: 30,
        minThumbExtent: 20,
      )!;

      expect(geometry.thumbExtent, 20);
      expect(geometry.thumbOffset + geometry.thumbExtent, 30);
      expect(geometry.scrollOffsetForThumbOffset(-10), 0);
      expect(geometry.scrollOffsetForThumbOffset(100), 10000);
    });

    test('rejects unusable track and viewport dimensions', () {
      expect(
        EditorScrollbarThumbGeometry.calculate(
          viewportExtent: 0,
          maxScrollExtent: 10,
          scrollOffset: 0,
          trackExtent: 20,
        ),
        isNull,
      );
      expect(
        EditorScrollbarThumbGeometry.calculate(
          viewportExtent: 10,
          maxScrollExtent: 10,
          scrollOffset: 0,
          trackExtent: double.infinity,
        ),
        isNull,
      );
    });
  });

  group('EditorScrollbar', () {
    late ScrollController controller;

    setUp(() {
      controller = ScrollController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildVerticalScrollbar({
      EditorScrollbarVisibility visibility = EditorScrollbarVisibility.auto,
    }) {
      return MaterialApp(
        home: EditorTheme(
          theme: EditorThemeData.darkModern,
          child: Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller,
                    child: const SizedBox(height: 480),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 12,
                    child: EditorScrollbar(
                      key: const ValueKey('test-scrollbar'),
                      axis: Axis.vertical,
                      controller: controller,
                      visibility: visibility,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('track click scrolls by one viewport page', (tester) async {
      await tester.pumpWidget(buildVerticalScrollbar());
      await tester.pumpAndSettle();

      final track = tester.getRect(
        find.byKey(const ValueKey('test-scrollbar')),
      );
      await tester.tapAt(Offset(track.center.dx, track.top + 80));
      await tester.pumpAndSettle();

      expect(controller.offset, 120);
    });

    testWidgets('thumb drag maps pointer movement to scroll position', (
      tester,
    ) async {
      await tester.pumpWidget(buildVerticalScrollbar());
      await tester.pumpAndSettle();

      final track = tester.getRect(
        find.byKey(const ValueKey('test-scrollbar')),
      );
      await tester.dragFrom(
        Offset(track.center.dx, track.top + 15),
        const Offset(0, 30),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(120, 0.1));
    });

    testWidgets('horizontal track click scrolls by one viewport page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditorTheme(
            theme: EditorThemeData.darkModern,
            child: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      child: const SizedBox(width: 480),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 12,
                      child: EditorScrollbar(
                        key: const ValueKey('test-horizontal-scrollbar'),
                        axis: Axis.horizontal,
                        controller: controller,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final track = tester.getRect(
        find.byKey(const ValueKey('test-horizontal-scrollbar')),
      );
      await tester.tapAt(Offset(track.left + 80, track.center.dy));
      await tester.pumpAndSettle();

      expect(controller.offset, 120);
    });

    testWidgets('hidden mode removes the scrollbar semantics', (tester) async {
      await tester.pumpWidget(
        buildVerticalScrollbar(visibility: EditorScrollbarVisibility.hidden),
      );

      expect(find.bySemanticsLabel('Editor vertical scrollbar'), findsNothing);
    });

    testWidgets('automatic mode reveals the scrollbar while hovered', (
      tester,
    ) async {
      await tester.pumpWidget(buildVerticalScrollbar());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Editor vertical scrollbar'), findsNothing);
      final track = tester.getRect(
        find.byKey(const ValueKey('test-scrollbar')),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: track.center);
      await mouse.moveTo(track.center);
      await tester.pump();

      expect(
        find.bySemanticsLabel('Editor vertical scrollbar'),
        findsOneWidget,
      );
      await mouse.removePointer();
    });

    testWidgets('multiline text fields do not add a native scrollbar', (
      tester,
    ) async {
      final textController = TextEditingController(text: 'line\n' * 40);
      final scrollController = ScrollController();
      addTearDown(textController.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ScrollConfiguration(
              behavior: const EditorScrollBehavior(),
              child: Scaffold(
                body: SizedBox(
                  height: 100,
                  child: TextField(
                    controller: textController,
                    scrollController: scrollController,
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('visible mode exposes a scrollbar even without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditorTheme(
            theme: EditorThemeData.darkModern,
            child: Scaffold(
              body: SizedBox(
                height: 100,
                child: EditorScrollbar(
                  axis: Axis.vertical,
                  controller: controller,
                  visibility: EditorScrollbarVisibility.visible,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Editor vertical scrollbar'),
        findsOneWidget,
      );
    });
  });
}
