import 'package:code_editor/core/lsp/protocol/lsp_types.dart';

class RangeOverlapMerger {
  const RangeOverlapMerger._();

  static List<LspRange> merge(Iterable<LspRange> ranges) {
    final sorted = ranges.toList()
      ..sort((a, b) {
        final start = _compare(a.start, b.start);
        return start == 0 ? _compare(a.end, b.end) : start;
      });
    if (sorted.isEmpty) return const [];

    final merged = <LspRange>[];
    var start = sorted.first.start;
    var end = sorted.first.end;
    for (final range in sorted.skip(1)) {
      if (_compare(range.start, end) <= 0) {
        if (_compare(range.end, end) > 0) end = range.end;
      } else {
        merged.add(LspRange(start: start, end: end));
        start = range.start;
        end = range.end;
      }
    }
    merged.add(LspRange(start: start, end: end));
    return List.unmodifiable(merged);
  }

  static int _compare(LspPosition left, LspPosition right) {
    final lines = left.line.compareTo(right.line);
    return lines == 0 ? left.character.compareTo(right.character) : lines;
  }
}
