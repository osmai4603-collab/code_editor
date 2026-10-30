import 'package:code_editor/core/lsp/protocol/lsp_types.dart';

import 'formatting_types.dart';

abstract interface class EditorFormattingService {
  String get id;

  Future<List<TextEdit>> formatDocument(
    FormattingOptions options, {
    LspRange? range,
  });

  Future<List<TextEdit>> formatRanges(
    FormattingOptions options,
    List<LspRange> ranges,
  );

  Future<List<TextEdit>> formatOnType(
    FormattingOptions options, {
    required LspPosition position,
    required String character,
  });
}
