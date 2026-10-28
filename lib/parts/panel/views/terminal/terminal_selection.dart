import '../../../../core/terminal/buffer/terminal_buffer.dart';

class TerminalSelection {
  int? startRow;
  int? startCol;
  int? endRow;
  int? endCol;

  bool get isActive => startRow != null && endRow != null;

  void start(int row, int col) {
    startRow = row;
    startCol = col;
    endRow = row;
    endCol = col;
  }

  void update(int row, int col) {
    if (!isActive) return;
    endRow = row;
    endCol = col;
  }

  void end() {}

  void clear() {
    startRow = null;
    startCol = null;
    endRow = null;
    endCol = null;
  }

  bool contains(int row, int col) {
    if (!isActive) return false;
    var start = (startRow!, startCol!);
    var end = (endRow!, endCol!);
    if (_after(start, end)) (start, end) = (end, start);
    if (row < start.$1 || row > end.$1) return false;
    if (start.$1 == end.$1) return col >= start.$2 && col <= end.$2;
    if (row == start.$1) return col >= start.$2;
    if (row == end.$1) return col <= end.$2;
    return true;
  }

  String getSelectedText(TerminalBuffer buffer, {int scrollOffset = 0}) {
    if (!isActive) return '';
    var start = (startRow!, startCol!);
    var end = (endRow!, endCol!);
    if (_after(start, end)) (start, end) = (end, start);
    final rows = <String>[];
    for (var row = start.$1; row <= end.$1; row++) {
      final line = buffer.lineAt(row, scrollOffset: scrollOffset);
      final from = row == start.$1 ? start.$2 : 0;
      final to = row == end.$1 ? end.$2 : line.cells.length - 1;
      rows.add(
        line.cells
            .skip(from.clamp(0, line.cells.length).toInt())
            .take((to - from + 1).clamp(0, line.cells.length).toInt())
            .map((cell) => cell.character)
            .join()
            .trimRight(),
      );
    }
    return rows.join('\n');
  }

  bool _after((int, int) left, (int, int) right) =>
      left.$1 > right.$1 || (left.$1 == right.$1 && left.$2 > right.$2);
}
