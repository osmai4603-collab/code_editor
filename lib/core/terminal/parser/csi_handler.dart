import '../models/terminal_cell.dart';
import '../models/terminal_state.dart';
import '../models/terminal_style.dart';

class CsiHandler {
  final TerminalState _state;

  CsiHandler(this._state);

  void handle(String params, String finalChar) {
    final private = params.startsWith('?');
    final values = params.replaceFirst(RegExp(r'^[?>!]'), '').split(';');
    final args = values.map((value) => int.tryParse(value) ?? 0).toList();
    int arg(int index, [int fallback = 1]) =>
        index >= args.length || args[index] == 0 ? fallback : args[index];
    final cursor = _state.cursor;
    final buffer = _state.buffer;

    switch (finalChar) {
      case 'A':
        cursor.moveRelative(
          -arg(0),
          0,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'B':
        cursor.moveRelative(
          arg(0),
          0,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'C':
      case 'a':
        cursor.moveRelative(
          0,
          arg(0),
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'D':
        cursor.moveRelative(
          0,
          -arg(0),
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'E':
        cursor.moveRelative(
          arg(0),
          0,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
        cursor.col = 0;
      case 'F':
        cursor.moveRelative(
          -arg(0),
          0,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
        cursor.col = 0;
      case 'G':
      case '`':
        cursor.moveTo(
          cursor.row,
          arg(0) - 1,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'd':
        cursor.moveTo(
          arg(0) - 1,
          cursor.col,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'H':
      case 'f':
        cursor.moveTo(
          arg(0) - 1,
          arg(1) - 1,
          maxRows: buffer.rows,
          maxCols: buffer.cols,
        );
      case 'J':
        _eraseDisplay(args.isEmpty ? 0 : args[0]);
      case 'K':
        _eraseLine(args.isEmpty ? 0 : args[0]);
      case 'X':
        _eraseCharacters(arg(0));
      case 'P':
        _deleteCharacters(arg(0));
      case '@':
        _insertCharacters(arg(0));
      case 'L':
        buffer.insertLines(cursor.row, arg(0), bottom: _state.scrollBottom);
      case 'M':
        buffer.deleteLines(cursor.row, arg(0), bottom: _state.scrollBottom);
      case 'S':
        buffer.scrollUp(
          lines: arg(0),
          top: _state.scrollTop,
          bottom: _state.scrollBottom,
        );
      case 'T':
        buffer.scrollDown(
          lines: arg(0),
          top: _state.scrollTop,
          bottom: _state.scrollBottom,
        );
      case 'r':
        _setScrollRegion(arg(0), arg(1, buffer.rows));
      case 'm':
        _setGraphicRendition(args);
      case 'h':
        _setMode(args, true, private);
      case 'l':
        _setMode(args, false, private);
      case 's':
        cursor.save();
      case 'u':
        cursor.restore(maxRows: buffer.rows, maxCols: buffer.cols);
      case 'c':
      case 'n':
        break;
    }
  }

  void _eraseDisplay(int mode) {
    final cursor = _state.cursor;
    final lines = _state.buffer.lines;
    if (mode == 2 || mode == 3) {
      for (final line in lines) {
        line.clear(_state.currentStyle);
      }
      if (mode == 3) _state.buffer.scrollback.clear();
      return;
    }
    if (mode == 0) {
      _eraseLine(0);
      for (var row = cursor.row + 1; row < lines.length; row++) {
        lines[row].clear(_state.currentStyle);
      }
    } else if (mode == 1) {
      for (var row = 0; row < cursor.row; row++) {
        lines[row].clear(_state.currentStyle);
      }
      _eraseLine(1);
    }
  }

  void _eraseLine(int mode) {
    final line = _state.buffer.lines[_state.cursor.row];
    final start = mode == 1 || mode == 2 ? 0 : _state.cursor.col;
    final end = mode == 0 || mode == 2
        ? line.cells.length
        : _state.cursor.col + 1;
    for (var col = start; col < end; col++) {
      line.cells[col] = TerminalCell.empty(_state.currentStyle);
    }
  }

  void _eraseCharacters(int count) {
    final line = _state.buffer.lines[_state.cursor.row];
    for (
      var col = _state.cursor.col;
      col < (_state.cursor.col + count).clamp(0, line.cells.length);
      col++
    ) {
      line.cells[col] = TerminalCell.empty(_state.currentStyle);
    }
  }

  void _deleteCharacters(int count) {
    final cells = _state.buffer.lines[_state.cursor.row].cells;
    final removed = count.clamp(0, cells.length - _state.cursor.col).toInt();
    cells.removeRange(_state.cursor.col, _state.cursor.col + removed);
    cells.addAll(
      List.generate(removed, (_) => TerminalCell.empty(_state.currentStyle)),
    );
  }

  void _insertCharacters(int count) {
    final cells = _state.buffer.lines[_state.cursor.row].cells;
    final inserted = count.clamp(0, cells.length - _state.cursor.col).toInt();
    cells.insertAll(
      _state.cursor.col,
      List.generate(inserted, (_) => TerminalCell.empty(_state.currentStyle)),
    );
    cells.removeRange(cells.length - inserted, cells.length);
  }

  void _setScrollRegion(int top, int bottom) {
    if (top < 1 || bottom > _state.buffer.rows || top >= bottom) return;
    _state.scrollTop = top - 1;
    _state.scrollBottom = bottom - 1;
    _state.cursor.moveTo(
      _state.scrollTop,
      0,
      maxRows: _state.buffer.rows,
      maxCols: _state.buffer.cols,
    );
  }

  void _setGraphicRendition(List<int> args) {
    if (args.isEmpty) args = [0];
    var index = 0;
    while (index < args.length) {
      final code = args[index];
      if (code == 0) {
        _state.currentStyle = TerminalStyle.defaultStyle;
      } else if (code == 1) {
        _updateStyle(bold: true);
      } else if (code == 2) {
        _updateStyle(dim: true);
      } else if (code == 3) {
        _updateStyle(italic: true);
      } else if (code == 4) {
        _updateStyle(underline: true);
      } else if (code == 7) {
        _updateStyle(inverse: true);
      } else if (code == 8) {
        _updateStyle(hidden: true);
      } else if (code == 9) {
        _updateStyle(strikethrough: true);
      } else if (code == 22) {
        _updateStyle(bold: false, dim: false);
      } else if (code == 23) {
        _updateStyle(italic: false);
      } else if (code == 24) {
        _updateStyle(underline: false);
      } else if (code == 27) {
        _updateStyle(inverse: false);
      } else if (code == 28) {
        _updateStyle(hidden: false);
      } else if (code == 29) {
        _updateStyle(strikethrough: false);
      } else if (code >= 30 && code <= 37) {
        _updateStyle(foregroundIndex: code - 30);
      } else if (code >= 40 && code <= 47) {
        _updateStyle(backgroundIndex: code - 40);
      } else if (code >= 90 && code <= 97) {
        _updateStyle(foregroundIndex: code - 90 + 8);
      } else if (code >= 100 && code <= 107) {
        _updateStyle(backgroundIndex: code - 100 + 8);
      } else if (code == 39) {
        _updateStyle(foregroundIndex: -1);
      } else if (code == 49) {
        _updateStyle(backgroundIndex: -1);
      } else if ((code == 38 || code == 48) && index + 1 < args.length) {
        final foreground = code == 38;
        final mode = args[index + 1];
        if (mode == 5 && index + 2 < args.length) {
          _updateStyle(
            foregroundIndex: foreground
                ? args[index + 2].clamp(0, 255).toInt()
                : null,
            backgroundIndex: foreground
                ? null
                : args[index + 2].clamp(0, 255).toInt(),
          );
          index += 2;
        } else if (mode == 2 && index + 4 < args.length) {
          final red = args[index + 2].clamp(0, 255).toInt();
          final green = args[index + 3].clamp(0, 255).toInt();
          final blue = args[index + 4].clamp(0, 255).toInt();
          final color = 0x1000000 | (red << 16) | (green << 8) | blue;
          _updateStyle(
            foregroundIndex: foreground ? color : null,
            backgroundIndex: foreground ? null : color,
          );
          index += 4;
        }
      }
      index++;
    }
  }

  void _updateStyle({
    int? foregroundIndex,
    int? backgroundIndex,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? dim,
    bool? inverse,
    bool? hidden,
  }) {
    _state.currentStyle = _state.currentStyle.copyWith(
      foregroundIndex: foregroundIndex,
      backgroundIndex: backgroundIndex,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      dim: dim,
      inverse: inverse,
      hidden: hidden,
    );
  }

  void _setMode(List<int> args, bool enabled, bool private) {
    if (!private) {
      if (args.contains(4)) _state.insertMode = enabled;
      return;
    }
    for (final mode in args) {
      switch (mode) {
        case 1:
          _state.applicationCursorKeys = enabled;
        case 25:
          _state.cursor.visible = enabled;
        case 47:
          if (enabled) {
            _state.enterAlternateBuffer(clear: false);
          } else {
            _state.leaveAlternateBuffer();
          }
        case 1047:
          if (enabled) {
            _state.enterAlternateBuffer();
          } else {
            _state.leaveAlternateBuffer();
          }
        case 1049:
          if (enabled) {
            _state.enterAlternateBuffer();
          } else {
            _state.leaveAlternateBuffer();
          }
        case 2004:
          _state.bracketedPasteMode = enabled;
        case 7:
          _state.autoWrapMode = enabled;
      }
    }
  }
}
