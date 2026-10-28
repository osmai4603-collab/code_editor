import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/file_system/models/file_tree_item.dart';
import 'package:code_editor/core/breadcrumbs/models/breadcrumb_symbol.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/layout/controllers/editor_controller.dart';
import 'package:code_editor/parts/editor/widgets/breadcrumbs/breadcrumbs_bar.dart';

void main() {
  late Directory workspace;
  late EditorDocumentsController documents;
  late String filePath;
  late String libPath;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('breadcrumbs-test-');
    final lib = Directory('${workspace.path}${Platform.pathSeparator}lib');
    await lib.create();
    libPath = lib.path;
    filePath = '${lib.path}${Platform.pathSeparator}main.dart';
    await File(filePath).writeAsString('void main() {}');
    documents = EditorDocumentsController();
  });

  tearDown(() async {
    documents.dispose();
    await workspace.delete(recursive: true);
  });

  Future<List<FileTreeItem>> listDirectory(String path) async {
    if (path == workspace.path) {
      return [FileTreeItem(name: 'lib', path: libPath, isDirectory: true)];
    }
    if (path == libPath) {
      return [
        FileTreeItem(name: 'main.dart', path: filePath, isDirectory: false),
      ];
    }
    return [];
  }

  Future<void> openFile(String path) async {
    documents.openFile(
      title: _basename(path),
      path: path,
      content: 'void main() {}',
      languageId: 'dart',
    );
  }

  Widget buildBar({
    List<BreadcrumbSymbol> symbols = const [],
    List<BreadcrumbSymbol> activeSymbols = const [],
    ValueChanged<BreadcrumbSymbol>? onSelectSymbol,
  }) => BreadcrumbsBar(
    filePath: filePath,
    workspacePath: workspace.path,
    listDirectory: listDirectory,
    openFile: openFile,
    symbols: symbols,
    activeSymbols: activeSymbols,
    symbolsLoading: false,
    symbolsError: null,
    onSelectSymbol: onSelectSymbol ?? (_) {},
  );

  Widget buildSubject() => MaterialApp(
    home: Scaffold(body: SizedBox(width: 600, height: 22, child: buildBar())),
  );

  testWidgets('opens a file selected through nested breadcrumb menus', (
    tester,
  ) async {
    documents.openFile(
      title: 'main.dart',
      path: filePath,
      content: 'unsaved text',
      languageId: 'dart',
    );
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byKey(ValueKey('breadcrumb-${workspace.path}')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('lib'), findsNWidgets(2));

    await tester.tap(find.byKey(ValueKey('breadcrumbs-file-$libPath')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('main.dart'), findsNWidgets(2));

    await tester.tap(find.byKey(ValueKey('breadcrumbs-file-$filePath')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(documents.activeTab?.path, filePath);
    expect(documents.tabs, hasLength(1));
    expect(documents.activeTab?.content, 'unsaved text');
  });

  testWidgets('keeps long paths within a narrow breadcrumb viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(140, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 90, height: 22, child: buildBar()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('starts breadcrumbs at the path beginning in RTL layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(width: 180, height: 22, child: buildBar()),
          ),
        ),
      ),
    );

    final firstBreadcrumb = tester.getRect(
      find.byKey(ValueKey('breadcrumb-${workspace.path}')),
    );
    expect(firstBreadcrumb.left, closeTo(8, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens child symbol choices and invokes the selection callback', (
    tester,
  ) async {
    final child = _symbol('child');
    final parent = _symbol('parent', children: [child]);
    BreadcrumbSymbol? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 22,
            child: buildBar(
              symbols: [parent],
              activeSymbols: [parent],
              onSelectSymbol: (symbol) => selected = symbol,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('breadcrumb-symbol-parent')));
    await tester.pumpAndSettle();
    expect(find.text('child'), findsOneWidget);
    await tester.tap(find.text('child'));
    await tester.pumpAndSettle();

    expect(selected, same(child));
  });
}

String _basename(String path) =>
    path.split(Platform.pathSeparator).where((part) => part.isNotEmpty).last;

BreadcrumbSymbol _symbol(
  String name, {
  List<BreadcrumbSymbol> children = const [],
}) {
  const range = LspRange(
    start: LspPosition(line: 0, character: 0),
    end: LspPosition(line: 2, character: 0),
  );
  return BreadcrumbSymbol(
    name: name,
    kind: LspSymbolKind.function,
    range: range,
    selectionRange: range,
    children: children,
  );
}
