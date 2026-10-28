import '../../lsp/protocol/lsp_types.dart';

class BreadcrumbSymbol {
  final String name;
  final LspSymbolKind kind;
  final LspRange range;
  final LspRange selectionRange;
  final String? containerName;
  final List<BreadcrumbSymbol> children;

  const BreadcrumbSymbol({
    required this.name,
    required this.kind,
    required this.range,
    required this.selectionRange,
    this.containerName,
    this.children = const [],
  });
}
