enum CursorShape { block, underline, bar }

class TerminalCursor {
  int row;
  int col;
  bool visible;
  CursorShape shape;
  bool blinking;
  int? _savedRow;
  int? _savedCol;

  TerminalCursor({
    this.row = 0,
    this.col = 0,
    this.visible = true,
    this.shape = CursorShape.block,
    this.blinking = true,
  });

  void save() {
    _savedRow = row;
    _savedCol = col;
  }

  void restore({int maxRows = 1, int maxCols = 1}) {
    if (_savedRow == null || _savedCol == null) return;
    moveTo(_savedRow!, _savedCol!, maxRows: maxRows, maxCols: maxCols);
  }

  void moveTo(int row, int col, {required int maxRows, required int maxCols}) {
    this.row = row.clamp(0, maxRows - 1).toInt();
    this.col = col.clamp(0, maxCols - 1).toInt();
  }

  void moveRelative(
    int dRow,
    int dCol, {
    required int maxRows,
    required int maxCols,
  }) {
    moveTo(row + dRow, col + dCol, maxRows: maxRows, maxCols: maxCols);
  }
}
