import '../models/terminal_cell.dart';
import '../models/terminal_style.dart';
import 'terminal_line.dart';
import 'terminal_scrollback.dart';

class TerminalBuffer {
  int _cols;
  int _rows;
  final List<TerminalLine> _lines;
  final TerminalScrollback scrollback;

  TerminalBuffer({
    required int cols,
    required int rows,
    int maxScrollback = 1000,
  }) : _cols = cols.clamp(1, 500).toInt(),
       _rows = rows.clamp(1, 200).toInt(),
       _lines = List.generate(
         rows.clamp(1, 200).toInt(),
         (_) => TerminalLine(cols.clamp(1, 500).toInt()),
       ),
       scrollback = TerminalScrollback(maxLines: maxScrollback);

  int get cols => _cols;
  int get rows => _rows;
  int get scrollbackLength => scrollback.length;
  List<TerminalLine> get lines => List.unmodifiable(_lines);

  TerminalCell cellAt(int row, int col) {
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) {
      return TerminalCell.empty();
    }
    return _lines[row].cells[col];
  }

  TerminalLine lineAt(int row, {int scrollOffset = 0}) {
    if (scrollOffset <= 0) return _lines[row.clamp(0, _rows - 1).toInt()];
    final absoluteIndex = scrollback.length - scrollOffset + row;
    if (absoluteIndex < 0) return _lines[0];
    if (absoluteIndex < scrollback.length) {
      return scrollback[absoluteIndex] ?? _lines[0];
    }
    return _lines[(absoluteIndex - scrollback.length)
        .clamp(0, _rows - 1)
        .toInt()];
  }

  TerminalLine? scrollbackLine(int index) => scrollback[index];

  void writeChar(
    String char,
    TerminalStyle style, {
    int row = 0,
    int col = 0,
    int width = 1,
  }) {
    if (row < 0 || row >= _rows || col < 0 || col >= _cols) return;
    final cells = _lines[row].cells;
    width = width.clamp(1, _cols - col).toInt();
    if (cells[col].width == 0 && col > 0) {
      cells[col - 1] = TerminalCell.empty();
    } else if (cells[col].width > 1 && col + 1 < _cols) {
      cells[col + 1] = TerminalCell.empty();
    }
    cells[col] = TerminalCell(character: char, style: style, width: width);
    for (var offset = 1; offset < width; offset++) {
      cells[col + offset] = TerminalCell(character: '', style: style, width: 0);
    }
  }

  void scrollUp({int lines = 1, int top = 0, int? bottom, bool save = true}) {
    final end = (bottom ?? _rows - 1).clamp(top, _rows - 1).toInt();
    final count = lines.clamp(1, end - top + 1).toInt();
    for (var index = 0; index < count; index++) {
      if (save && top == 0 && end == _rows - 1) {
        scrollback.add(_lines.removeAt(top));
      } else {
        _lines.removeAt(top);
      }
      _lines.insert(end, TerminalLine(_cols));
    }
  }

  void scrollDown({int lines = 1, int top = 0, int? bottom}) {
    final end = (bottom ?? _rows - 1).clamp(top, _rows - 1).toInt();
    final count = lines.clamp(1, end - top + 1).toInt();
    for (var index = 0; index < count; index++) {
      _lines.removeAt(end);
      _lines.insert(top, TerminalLine(_cols));
    }
  }

  void insertLines(int row, int count, {int? bottom}) {
    final end = (bottom ?? _rows - 1).clamp(row, _rows - 1).toInt();
    final safeCount = count.clamp(1, end - row + 1).toInt();
    for (var index = 0; index < safeCount; index++) {
      _lines.removeAt(end);
      _lines.insert(row, TerminalLine(_cols));
    }
  }

  void deleteLines(int row, int count, {int? bottom}) {
    final end = (bottom ?? _rows - 1).clamp(row, _rows - 1).toInt();
    final safeCount = count.clamp(1, end - row + 1).toInt();
    for (var index = 0; index < safeCount; index++) {
      _lines.removeAt(row);
      _lines.insert(end, TerminalLine(_cols));
    }
  }

  void clear() {
    for (final line in _lines) {
      line.clear();
    }
    scrollback.clear();
  }

  void resize(int newCols, int newRows) {
    newCols = newCols.clamp(1, 500).toInt();
    newRows = newRows.clamp(1, 200).toInt();
    for (final line in _lines) {
      line.resize(newCols);
    }
    if (newRows < _rows) {
      final removed = _rows - newRows;
      for (var index = 0; index < removed; index++) {
        scrollback.add(_lines.removeAt(0));
      }
    } else if (newRows > _rows) {
      _lines.addAll(
        List.generate(newRows - _rows, (_) => TerminalLine(newCols)),
      );
    }
    _cols = newCols;
    _rows = newRows;
  }
}
