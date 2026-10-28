import '../models/terminal_state.dart';

class EscapeHandler {
  final TerminalState _state;

  EscapeHandler(this._state);

  void handle(String char) {
    final cursor = _state.cursor;
    switch (char) {
      case '7':
        cursor.save();
      case '8':
        cursor.restore(
          maxRows: _state.buffer.rows,
          maxCols: _state.buffer.cols,
        );
      case 'D':
        _index();
      case 'E':
        cursor.col = 0;
        _index();
      case 'M':
        if (cursor.row == _state.scrollTop) {
          _state.buffer.scrollDown(
            top: _state.scrollTop,
            bottom: _state.scrollBottom,
          );
        } else {
          cursor.moveRelative(
            -1,
            0,
            maxRows: _state.buffer.rows,
            maxCols: _state.buffer.cols,
          );
        }
      case 'c':
        _state.reset();
    }
  }

  void _index() {
    final cursor = _state.cursor;
    if (cursor.row == _state.scrollBottom) {
      _state.buffer.scrollUp(
        top: _state.scrollTop,
        bottom: _state.scrollBottom,
      );
    } else {
      cursor.moveRelative(
        1,
        0,
        maxRows: _state.buffer.rows,
        maxCols: _state.buffer.cols,
      );
    }
  }
}
