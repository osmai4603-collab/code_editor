import '../../lsp/protocol/lsp_types.dart';
import '../models/breadcrumb_symbol.dart';

class BreadcrumbSymbolPathService {
  const BreadcrumbSymbolPathService();

  List<BreadcrumbSymbol> pathAtPosition(
    List<BreadcrumbSymbol> symbols,
    LspPosition position,
  ) {
    final symbol = _smallestContaining(symbols, position);
    if (symbol == null) return const [];
    final parentPath = pathAtPosition(symbol.children, position);
    return List.unmodifiable([symbol, ...parentPath]);
  }

  bool _contains(BreadcrumbSymbol symbol, LspPosition position) {
    return _compare(symbol.range.start, position) <= 0 &&
        _compare(position, symbol.range.end) < 0;
  }

  BreadcrumbSymbol? _smallestContaining(
    List<BreadcrumbSymbol> symbols,
    LspPosition position,
  ) {
    final matches =
        symbols.where((symbol) => _contains(symbol, position)).toList()
          ..sort((left, right) {
            final start = _compare(left.range.start, right.range.start);
            if (start != 0) return start;
            return _compare(right.range.end, left.range.end);
          });
    return matches.isEmpty ? null : matches.first;
  }

  int _compare(LspPosition left, LspPosition right) {
    final line = left.line.compareTo(right.line);
    return line != 0 ? line : left.character.compareTo(right.character);
  }
}
