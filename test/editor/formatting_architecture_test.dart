import 'dart:io';

import 'package:code_editor/core/editor/formatting/conflicts/default_formatter_service.dart';
import 'package:code_editor/core/editor/formatting/contracts/formatting_types.dart';
import 'package:code_editor/core/editor/formatting/diff/formatting_diff_engine.dart';
import 'package:code_editor/core/editor/formatting/editor_formatting_preferences.dart';
import 'package:code_editor/core/editor/formatting/execution/range_overlap_merger.dart';
import 'package:code_editor/core/editor/formatting/execution/formatting_execution_pipeline.dart';
import 'package:code_editor/core/editor/formatting/execution/scm_quick_diff_adapter.dart';
import 'package:code_editor/core/editor/formatting/registry/formatting_provider_registry.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _RangeProvider implements DocumentRangeFormattingEditProvider {
  @override
  String get id => 'range';

  @override
  Set<String> get languageIds => const {'dart'};

  LspRange? requestedRange;

  @override
  Future<List<TextEdit>> provideDocumentRangeFormattingEdits(
    FormattingDocument document,
    LspRange range,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) async {
    requestedRange = range;
    return const [];
  }
}

void main() {
  test('registers range providers as synthetic document providers', () async {
    final registry = FormattingProviderRegistry();
    final provider = _RangeProvider();
    final registration = registry.registerRangeProvider(provider);
    const document = FormattingDocument(
      uri: 'file:///main.dart',
      languageId: 'dart',
      text: 'first\r\nlast',
    );
    final documentProviders = registry.documentProvidersFor(document);

    expect(documentProviders, hasLength(1));
    await documentProviders.single.provideDocumentFormattingEdits(
      document,
      const FormattingOptions(tabSize: 2, insertSpaces: true),
    );
    expect(
      provider.requestedRange?.start,
      const LspPosition(line: 0, character: 0),
    );
    expect(
      provider.requestedRange?.end,
      const LspPosition(line: 1, character: 4),
    );

    registration.dispose();
    expect(registry.documentProvidersFor(document), isEmpty);
  });

  test('merges overlapping and touching ranges in document order', () {
    final ranges = RangeOverlapMerger.merge(const [
      LspRange(
        start: LspPosition(line: 2, character: 0),
        end: LspPosition(line: 4, character: 0),
      ),
      LspRange(
        start: LspPosition(line: 1, character: 0),
        end: LspPosition(line: 2, character: 0),
      ),
      LspRange(
        start: LspPosition(line: 6, character: 0),
        end: LspPosition(line: 6, character: 2),
      ),
    ]);

    expect(ranges.map((range) => '${range.start}-${range.end}'), [
      '1:0-4:0',
      '6:0-6:2',
    ]);
  });

  test(
    'diff worker preserves the document EOL and ignores identical text',
    () async {
      const engine = FormattingDiffEngine();

      final normalized = await engine.compute('a\r\nb\r\n', 'a\nformatted\n');
      expect(normalized, hasLength(1));
      expect(normalized.single.insertedText, 'formatted');
      expect(await engine.compute('same', 'same'), isEmpty);
      final oversized = await engine.compute('a', 'b', diffLimit: 1);
      expect(oversized.single.insertedText, 'b');
    },
  );

  test('diff worker keeps separated changes as independent edits', () async {
    const engine = FormattingDiffEngine();

    final edits = await engine.compute('one two three', 'ONE two THREE');

    expect(edits, hasLength(2));
    expect(edits[0].start, 0);
    expect(edits[0].removedLength, 3);
    expect(edits[0].insertedText, 'ONE');
    expect(edits[1].start, 8);
    expect(edits[1].removedLength, 5);
    expect(edits[1].insertedText, 'THREE');
  });

  test('diff worker edits reconstruct the normalized formatted text', () async {
    const engine = FormattingDiffEngine();
    const examples = [
      ('', 'insert'),
      ('delete', ''),
      ('abc', 'axc'),
      ('ab', 'ba'),
      ('kitten', 'sitting'),
      ('😀 old', '😀 new'),
    ];

    for (final (original, formatted) in examples) {
      final edits = await engine.compute(original, formatted);
      var reconstructed = original;
      for (final edit in edits.reversed) {
        reconstructed = reconstructed.replaceRange(
          edit.start,
          edit.start + edit.removedLength,
          edit.insertedText,
        );
      }
      expect(reconstructed, formatted, reason: '$original -> $formatted');
    }
  });

  test('diff worker falls back when edit distance exceeds its bound', () async {
    const engine = FormattingDiffEngine();

    final edits = await engine.compute('a' * 1100, 'b' * 1100, diffLimit: 3000);

    expect(edits, hasLength(1));
    expect(edits.single.start, 0);
    expect(edits.single.removedLength, 1100);
    expect(edits.single.insertedText, 'b' * 1100);
  });

  test('default formatter service resolves configured formatter', () {
    final registry = FormattingProviderRegistry();
    final provider = _RangeProvider();
    registry.registerRangeProvider(provider);
    final providers = registry.documentProvidersFor(
      const FormattingDocument(
        uri: 'file:///main.dart',
        languageId: 'dart',
        text: '',
      ),
    );
    final resolution = const DefaultFormatterService().resolve(
      providers: providers,
      preferences: const EditorFormattingPreferences(defaultFormatter: 'range'),
      languageId: 'dart',
      kind: FormattingKind.file,
      mode: FormattingMode.explicit,
    );

    expect(resolution.status, FormatterResolutionStatus.selected);
    expect(
      resolution.provider,
      isA<DocumentFormattingEditProvider>().having(
        (provider) => provider.id,
        'provider id',
        'range',
      ),
    );
  });

  test('default formatter service requests a choice for explicit conflicts', () {
    final formatter = _RangeProvider();
    final resolution = const DefaultFormatterService().resolve(
      providers: [formatter, _DocumentProvider()],
      preferences: const EditorFormattingPreferences(),
      languageId: 'dart',
      kind: FormattingKind.file,
      mode: FormattingMode.explicit,
    );

    expect(
      resolution.status,
      FormatterResolutionStatus.formatterChoiceRequired,
    );
  });

  test('SCM adapter maps changed Git hunks to valid document ranges', () async {
    final adapter = ScmQuickDiffAdapter(
      runProcess: (executable, arguments) async {
        if (arguments.contains('diff')) {
          return ProcessResult(
            1,
            0,
            '@@ -2,2 +2,2 @@\n-old\n+new\n',
            '',
          );
        }
        return ProcessResult(1, 0, '', '');
      },
    );

    final ranges = await adapter.modifiedRanges(
      workspacePath: Directory.current.path,
      filePath: '${Directory.current.path}/lib/example.dart',
      documentText: 'one\ntwo\nthree',
    );

    expect(ranges, hasLength(1));
    expect(ranges!.single.start, const LspPosition(line: 1, character: 0));
    expect(ranges.single.end, const LspPosition(line: 2, character: 5));
  });

  test('SCM adapter reports when the file has no Git baseline', () async {
    final adapter = ScmQuickDiffAdapter(
      runProcess: (executable, arguments) async =>
          ProcessResult(1, 128, '', 'fatal: not a git repository'),
    );

    final ranges = await adapter.modifiedRanges(
      workspacePath: Directory.current.path,
      filePath: '${Directory.current.path}/lib/example.dart',
      documentText: '',
    );

    expect(ranges, isNull);
  });

  test('execution pipeline applies minimal changes and preserves selection', () async {
    const pipeline = FormattingExecutionPipeline();
    const current = TextEditingValue(
      text: 'one two three',
      selection: TextSelection.collapsed(offset: 6),
    );
    const edits = [
      TextEdit(
        range: LspRange(
          start: LspPosition(line: 0, character: 0),
          end: LspPosition(line: 0, character: 3),
        ),
        newText: 'ONE',
      ),
      TextEdit(
        range: LspRange(
          start: LspPosition(line: 0, character: 8),
          end: LspPosition(line: 0, character: 13),
        ),
        newText: 'THREE',
      ),
    ];

    final result = await pipeline.apply(current, edits);

    expect(result.text, 'ONE two THREE');
    expect(result.selection.extentOffset, 6);
  });
}

class _DocumentProvider implements DocumentFormattingEditProvider {
  @override
  String get id => 'document';

  @override
  Set<String> get languageIds => const {'dart'};

  @override
  Future<List<TextEdit>> provideDocumentFormattingEdits(
    FormattingDocument document,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) async => const [];
}
