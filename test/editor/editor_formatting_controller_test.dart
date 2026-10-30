import 'dart:async';
import 'dart:io';

import 'package:code_editor/core/editor/formatting/contracts/editor_formatting_service.dart';
import 'package:code_editor/core/editor/formatting/contracts/formatting_types.dart';
import 'package:code_editor/core/editor/formatting/editor_formatting_preferences.dart';
import 'package:code_editor/core/editor/formatting/execution/scm_quick_diff_adapter.dart';
import 'package:code_editor/core/editor/indentation/editor_indentation_options.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:code_editor/parts/editor/controllers/code_editor_controller.dart';
import 'package:code_editor/parts/editor/formatting/editor_formatting_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Formatter
    implements
        EditorFormattingService,
        DocumentFormattingEditProvider,
        DocumentRangeFormattingEditProvider {
  @override
  String get id => 'test-formatter';

  @override
  Set<String> get languageIds => const {'dart'};

  final List<LspRange> requestedRanges = [];

  @override
  Future<List<TextEdit>> formatDocument(
    FormattingOptions options, {
    LspRange? range,
  }) async => [_replaceAll('formatted')];

  @override
  Future<List<TextEdit>> formatRanges(
    FormattingOptions options,
    List<LspRange> ranges,
  ) async {
    requestedRanges.addAll(ranges);
    return [_replaceAll('modified')];
  }

  @override
  Future<List<TextEdit>> formatOnType(
    FormattingOptions options, {
    required LspPosition position,
    required String character,
  }) async => const [];

  @override
  Future<List<TextEdit>> provideDocumentFormattingEdits(
    FormattingDocument document,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) => formatDocument(options);

  @override
  Future<List<TextEdit>> provideDocumentRangeFormattingEdits(
    FormattingDocument document,
    LspRange range,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) async {
    requestedRanges.add(range);
    return [_replaceAll('modified')];
  }

  TextEdit _replaceAll(String value) => TextEdit(
    range: LspRange(
      start: const LspPosition(line: 0, character: 0),
      end: const LspPosition(line: 0, character: 3),
    ),
    newText: value,
  );
}

class _DelayedFormatter extends _Formatter {
  final Completer<List<TextEdit>> response = Completer<List<TextEdit>>();
  FormattingCancellationToken? cancellationToken;

  @override
  Future<List<TextEdit>> provideDocumentFormattingEdits(
    FormattingDocument document,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) {
    this.cancellationToken = cancellationToken;
    return response.future;
  }
}

void main() {
  test('format-on-save file mode applies formatter edits', () async {
    final editor = CodeEditorController(text: 'old', filePath: '/tmp/a.dart');
    final formatter = _Formatter();
    final controller = EditorFormattingController(
      editorController: editor,
      service: formatter,
      preferences: () => const EditorFormattingPreferences(
        formatOnSave: true,
        formatOnSaveMode: FormatOnSaveMode.file,
      ),
      languageId: () => 'dart',
      indentationOptions: () => const EditorIndentationOptions(),
      isMounted: () => true,
      onError: fail,
      onFormatted: () {},
      workspacePath: null,
      filePath: '/tmp/a.dart',
    );
    addTearDown(() {
      controller.dispose();
      editor.dispose();
    });

    await controller.formatOnSave();

    expect(editor.text, 'formatted');
    expect(controller.undoLastFormatting(), isTrue);
    expect(editor.text, 'old');
    expect(controller.undoLastFormatting(), isFalse);
  });

  test(
    'user edits cancel pending formatting and discard its result',
    () async {
      final editor = CodeEditorController(text: 'old', filePath: '/tmp/a.dart');
      final formatter = _DelayedFormatter();
      final controller = EditorFormattingController(
        editorController: editor,
        service: formatter,
        preferences: () => const EditorFormattingPreferences(),
        languageId: () => 'dart',
        indentationOptions: () => const EditorIndentationOptions(),
        isMounted: () => true,
        onError: fail,
        onFormatted: () {},
        workspacePath: null,
        filePath: '/tmp/a.dart',
      );
      addTearDown(() {
        controller.dispose();
        editor.dispose();
      });

      final formatting = controller.formatDocument();
      final cancellationToken = formatter.cancellationToken;
      expect(cancellationToken, isNotNull);

      controller.recordUserEdit();

      expect(cancellationToken!.isCancellationRequested, isTrue);
      formatter.response.complete([formatter._replaceAll('formatted')]);
      await formatting;
      expect(editor.text, 'old');
    },
  );

  test(
    'format-on-save modifications mode formats Git changed ranges',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'formatting_git_ranges_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final editor = CodeEditorController(
        text: 'old',
        filePath: '${workspace.path}/a.dart',
      );
      final formatter = _Formatter();
      final controller = EditorFormattingController(
        editorController: editor,
        service: formatter,
        preferences: () => const EditorFormattingPreferences(
          formatOnSave: true,
          formatOnSaveMode: FormatOnSaveMode.modifications,
        ),
        languageId: () => 'dart',
        indentationOptions: () => const EditorIndentationOptions(),
        isMounted: () => true,
        onError: fail,
        onFormatted: () {},
        workspacePath: workspace.path,
        filePath: '${workspace.path}/a.dart',
        scmQuickDiffAdapter: ScmQuickDiffAdapter(
          runProcess: (executable, arguments) async {
            if (arguments.contains('diff')) {
              return ProcessResult(1, 0, '@@ -1 +1 @@\n-old\n+new\n', '');
            }
            return ProcessResult(1, 0, '', '');
          },
        ),
      );
      addTearDown(() {
        controller.dispose();
        editor.dispose();
      });

      await controller.formatOnSave();

      expect(editor.text, 'modified');
      expect(formatter.requestedRanges, hasLength(1));
    },
  );

  test(
    'modifications-if-available falls back to full-document formatting',
    () async {
      final editor = CodeEditorController(text: 'old', filePath: '/tmp/a.dart');
      final formatter = _Formatter();
      final controller = EditorFormattingController(
        editorController: editor,
        service: formatter,
        preferences: () => const EditorFormattingPreferences(
          formatOnSave: true,
          formatOnSaveMode: FormatOnSaveMode.modificationsIfAvailable,
        ),
        languageId: () => 'dart',
        indentationOptions: () => const EditorIndentationOptions(),
        isMounted: () => true,
        onError: fail,
        onFormatted: () {},
        workspacePath: null,
        filePath: '/tmp/a.dart',
      );
      addTearDown(() {
        controller.dispose();
        editor.dispose();
      });

      await controller.formatOnSave();

      expect(editor.text, 'formatted');
    },
  );
}
