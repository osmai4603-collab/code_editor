import 'package:code_editor/core/lsp/protocol/lsp_types.dart';

enum FormattingMode { explicit, silent }

enum FormattingKind { file, selection }

class FormattingDocument {
  final String uri;
  final String languageId;
  final String text;

  const FormattingDocument({
    required this.uri,
    required this.languageId,
    required this.text,
  });
}

class FormattingOptions {
  final int tabSize;
  final bool insertSpaces;
  final Map<String, Object?> additionalProperties;

  const FormattingOptions({
    required this.tabSize,
    required this.insertSpaces,
    this.additionalProperties = const {},
  });
}

abstract interface class FormattingCancellationToken {
  bool get isCancellationRequested;
}

abstract interface class DocumentFormattingEditProvider {
  String get id;
  Set<String> get languageIds;

  Future<List<TextEdit>> provideDocumentFormattingEdits(
    FormattingDocument document,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  });
}

abstract interface class DocumentRangeFormattingEditProvider {
  String get id;
  Set<String> get languageIds;

  Future<List<TextEdit>> provideDocumentRangeFormattingEdits(
    FormattingDocument document,
    LspRange range,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  });
}

abstract interface class DocumentMultiRangeFormattingEditProvider {
  String get id;
  Set<String> get languageIds;

  Future<List<TextEdit>> provideDocumentMultiRangeFormattingEdits(
    FormattingDocument document,
    List<LspRange> ranges,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  });
}

abstract interface class OnTypeFormattingEditProvider {
  String get id;
  Set<String> get languageIds;
  Set<String> get triggerCharacters;

  Future<List<TextEdit>> provideOnTypeFormattingEdits(
    FormattingDocument document,
    LspPosition position,
    String character,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  });
}
