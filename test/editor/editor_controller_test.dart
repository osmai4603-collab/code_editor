import 'dart:io';

import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/core/editor/indentation/editor_indentation_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EditorDocumentsController controller;
  late Directory tempDirectory;

  setUp(() async {
    controller = EditorDocumentsController();
    tempDirectory = await Directory.systemTemp.createTemp('code_editor_tabs_');
  });

  tearDown(() async {
    controller.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('preview tabs are replaced until pinned, then remain open', () {
    controller.openFile(
      title: 'first.dart',
      path: '${tempDirectory.path}/first.dart',
      content: 'first',
      isPreview: true,
    );
    controller.openFile(
      title: 'second.dart',
      path: '${tempDirectory.path}/second.dart',
      content: 'second',
      isPreview: true,
    );

    expect(controller.tabs.map((tab) => tab.title), ['second.dart']);
    controller.pinTab(controller.activeTab!.id);
    controller.openFile(
      title: 'third.dart',
      path: '${tempDirectory.path}/third.dart',
      content: 'third',
      isPreview: true,
    );

    expect(controller.tabs.map((tab) => tab.title), [
      'second.dart',
      'third.dart',
    ]);
    expect(controller.tabs.first.isPreview, isFalse);
    expect(controller.activeTab!.isPreview, isTrue);
  });

  test('dirty preview is pinned when another preview opens', () {
    controller.openFile(
      title: 'first.dart',
      path: '${tempDirectory.path}/first.dart',
      content: 'first',
      isPreview: true,
    );
    final firstId = controller.activeTab!.id;
    controller.updateContent(firstId, 'changed');
    controller.openFile(
      title: 'second.dart',
      path: '${tempDirectory.path}/second.dart',
      content: 'second',
      isPreview: true,
    );

    expect(controller.tabs, hasLength(2));
    expect(controller.tabs.first.isPreview, isFalse);
    expect(controller.tabs.first.isDirty, isTrue);
  });

  test('saving a dirty tab writes its content to disk', () async {
    final file = File('${tempDirectory.path}/save.dart');
    await file.writeAsString('original');
    controller.openFile(
      title: 'save.dart',
      path: file.path,
      content: 'original',
    );
    controller.updateContent(controller.activeTab!.id, 'saved content');

    await controller.saveCurrentTab();

    expect(await file.readAsString(), 'saved content');
    expect(controller.activeTab!.isDirty, isFalse);
  });

  test('indentation preferences are retained with their open tab', () {
    controller.openFile(
      title: 'settings.dart',
      path: '${tempDirectory.path}/settings.dart',
      content: 'void main() {}',
    );
    final tab = controller.activeTab!;
    const options = EditorIndentationOptions(
      tabSize: 8,
      indentSize: 2,
      insertSpaces: false,
      detectIndentation: false,
    );

    controller.updateIndentationOptions(tab.id, options);

    expect(controller.activeTab!.indentationOptions, options);
  });

  test('navigation requests retain the target resource and LSP position', () {
    controller.requestNavigation(
      path: '${tempDirectory.path}/target.dart',
      line: 12,
      character: 7,
    );

    expect(controller.navigationRequest, isNotNull);
    expect(
      controller.navigationRequest!.path,
      '${tempDirectory.path}/target.dart',
    );
    expect(controller.navigationRequest!.line, 12);
    expect(controller.navigationRequest!.character, 7);
  });
}
