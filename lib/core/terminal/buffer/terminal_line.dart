import '../models/terminal_cell.dart';
import '../models/terminal_style.dart';

class TerminalLine {
  final List<TerminalCell> cells;
  bool isWrapped;

  TerminalLine(int cols)
    : cells = List.generate(cols, (_) => TerminalCell.empty()),
      isWrapped = false;

  void resize(int newCols) {
    if (newCols < cells.length) {
      cells.removeRange(newCols, cells.length);
    } else if (newCols > cells.length) {
      cells.addAll(
        List.generate(newCols - cells.length, (_) => TerminalCell.empty()),
      );
    }
  }

  void clear([TerminalStyle? style]) {
    for (var index = 0; index < cells.length; index++) {
      cells[index] = TerminalCell.empty(style ?? TerminalStyle.defaultStyle);
    }
    isWrapped = false;
  }

  String toPlainText() => cells.map((cell) => cell.character).join();

  TerminalLine copy() {
    final copy = TerminalLine(cells.length)..isWrapped = isWrapped;
    for (var index = 0; index < cells.length; index++) {
      copy.cells[index] = cells[index].copy();
    }
    return copy;
  }
}
