import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/theme/editor_theme.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/parts/panel/views/execution_output_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ExecutionController execution;
  late EditorDocumentsController documents;

  setUp(() {
    execution = ExecutionController();
    documents = EditorDocumentsController();
  });

  tearDown(() {
    execution.dispose();
    documents.dispose();
  });

  Widget testApp() => MaterialApp(
    home: EditorTheme(
      theme: EditorThemeData.darkModern,
      child: EditorDocumentsScope(
        notifier: documents,
        child: Scaffold(
          body: ExecutionOutputView(executionController: execution),
        ),
      ),
    ),
  );

  testWidgets('selects and searches execution output sessions', (tester) async {
    await tester.runAsync(
      () => execution.executeCommand(
        command: 'echo',
        args: ['first needle output'],
      ),
    );
    await tester.runAsync(
      () => execution.executeCommand(command: 'echo', args: ['second output']),
    );
    expect(execution.history, hasLength(2));
    expect(
      execution.activeSession!.lines.map((line) => line.text),
      contains('second output'),
    );

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.text('second output'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('first needle output').last);
    await tester.pumpAndSettle();
    expect(find.text('first needle output'), findsOneWidget);
    expect(find.text('second output'), findsNothing);

    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pumpAndSettle();
    expect(find.text('first needle output'), findsOneWidget);
    expect(find.text('Executing: echo first needle output'), findsOneWidget);
  });

  testWidgets('clears only the selected execution session', (tester) async {
    await tester.runAsync(
      () => execution.executeCommand(command: 'echo', args: ['first output']),
    );
    final firstSession = execution.activeSession!;
    await tester.runAsync(
      () => execution.executeCommand(command: 'echo', args: ['second output']),
    );

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('first output').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear selected output'));
    await tester.pumpAndSettle();

    expect(firstSession.lines, isEmpty);
    expect(find.text('This execution has no output yet.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('second output').last);
    await tester.pumpAndSettle();
    expect(find.text('second output'), findsOneWidget);
  });
}
