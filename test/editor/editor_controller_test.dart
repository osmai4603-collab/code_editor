import 'dart:io';

import 'package:code_editor/layout/controllers/editor_controller.dart';
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
}
