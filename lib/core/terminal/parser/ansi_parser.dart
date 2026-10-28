import '../models/terminal_cell.dart';
import '../models/terminal_state.dart';
import 'csi_handler.dart';
import 'escape_handler.dart';
import 'osc_handler.dart';

enum _ParserState {
  ground,
  escape,
  csi,
  osc,
  oscEscape,
  ignoreString,
  ignoreEscape,
}

class AnsiParser {
  final TerminalState _state;
  late final CsiHandler _csiHandler = CsiHandler(_state);
  late final OscHandler _oscHandler = OscHandler(_state);
  late final EscapeHandler _escapeHandler = EscapeHandler(_state);
  _ParserState _parserState = _ParserState.ground;
  final StringBuffer _sequenceBuffer = StringBuffer();

  AnsiParser(this._state);

  void write(String data) {
    for (final rune in data.runes) {
      _processChar(rune);
    }
    _state.notify();
  }

  void _processChar(int code) {
    switch (_parserState) {
      case _ParserState.ground:
        _handleGround(code);
      case _ParserState.escape:
        _handleEscape(code);
      case _ParserState.csi:
        _handleCsi(code);
      case _ParserState.osc:
        _handleOsc(code);
      case _ParserState.oscEscape:
        if (code == 0x5C) {
          _finishOsc();
        } else {
          _sequenceBuffer.writeCharCode(0x1B);
          _sequenceBuffer.writeCharCode(code);
          _parserState = _ParserState.osc;
        }
      case _ParserState.ignoreString:
        if (code == 0x07) _resetSequence();
        if (code == 0x1B) _parserState = _ParserState.ignoreEscape;
      case _ParserState.ignoreEscape:
        if (code == 0x5C) {
          _resetSequence();
        } else if (code != 0x1B) {
          _parserState = _ParserState.ignoreString;
        }
    }
  }

  void _handleGround(int code) {
    if (code == 0x1B) {
      _parserState = _ParserState.escape;
    } else if (code == 0x08) {
      _state.cursor.moveRelative(
        0,
        -1,
        maxRows: _state.buffer.rows,
        maxCols: _state.buffer.cols,
      );
    } else if (code == 0x09) {
      final nextTab = ((_state.cursor.col ~/ 8) + 1) * 8;
      _state.cursor.col = nextTab.clamp(0, _state.buffer.cols - 1).toInt();
    } else if (code == 0x0A || code == 0x0B || code == 0x0C) {
      _lineFeed();
    } else if (code == 0x0D) {
      _state.cursor.col = 0;
    } else if (code >= 0x20 && code != 0x7F) {
      _writeCharacter(String.fromCharCode(code), code);
    }
  }

  void _handleEscape(int code) {
    if (code == 0x5B) {
      _sequenceBuffer.clear();
      _parserState = _ParserState.csi;
    } else if (code == 0x5D) {
      _sequenceBuffer.clear();
      _parserState = _ParserState.osc;
    } else if (code == 0x50 || code == 0x5E || code == 0x5F) {
      _sequenceBuffer.clear();
      _parserState = _ParserState.ignoreString;
    } else {
      _escapeHandler.handle(String.fromCharCode(code));
      _resetSequence();
    }
  }

  void _handleCsi(int code) {
    if (code >= 0x40 && code <= 0x7E) {
      _csiHandler.handle(_sequenceBuffer.toString(), String.fromCharCode(code));
      _resetSequence();
    } else if (code >= 0x20 && code <= 0x3F) {
      if (_sequenceBuffer.length < 256) _sequenceBuffer.writeCharCode(code);
    } else if (code == 0x1B) {
      _parserState = _ParserState.escape;
      _sequenceBuffer.clear();
    } else if (code < 0x20) {
      _handleGround(code);
    } else {
      _resetSequence();
    }
  }

  void _handleOsc(int code) {
    if (code == 0x07) {
      _finishOsc();
    } else if (code == 0x1B) {
      _parserState = _ParserState.oscEscape;
    } else if (_sequenceBuffer.length < 4096) {
      _sequenceBuffer.writeCharCode(code);
    } else {
      _resetSequence();
    }
  }

  void _finishOsc() {
    _oscHandler.handle(_sequenceBuffer.toString());
    _resetSequence();
  }

  void _writeCharacter(String character, int codePoint) {
    final cursor = _state.cursor;
    if (_isCombining(codePoint)) {
      if (cursor.col > 0) {
        final cells = _state.buffer.lines[cursor.row].cells;
        var previousCol = cursor.col - 1;
        if (cells[previousCol].width == 0) previousCol--;
        if (previousCol < 0) return;
        final previous = cells[previousCol];
        previous.character += character;
      }
      return;
    }
    var width = _isWide(codePoint) ? 2 : 1;
    if (width > _state.buffer.cols) width = 1;
    if (cursor.col >= _state.buffer.cols) {
      if (!_state.autoWrapMode) {
        cursor.col = _state.buffer.cols - width;
      } else {
        _state.buffer.lines[cursor.row].isWrapped = true;
        cursor.col = 0;
        _lineFeed();
      }
    }
    if (cursor.col + width > _state.buffer.cols) {
      if (_state.autoWrapMode) {
        _state.buffer.lines[cursor.row].isWrapped = true;
        cursor.col = 0;
        _lineFeed();
      } else {
        cursor.col = _state.buffer.cols - width;
      }
    }
    if (_state.insertMode) {
      final cells = _state.buffer.lines[cursor.row].cells;
      cells.insertAll(
        cursor.col,
        List.generate(width, (_) => TerminalCell.empty()),
      );
      cells.removeRange(cells.length - width, cells.length);
    }
    _state.buffer.writeChar(
      character,
      _state.currentStyle,
      row: cursor.row,
      col: cursor.col,
      width: width,
    );
    cursor.col += width;
  }

  bool _isCombining(int codePoint) =>
      (codePoint >= 0x0300 && codePoint <= 0x036F) ||
      (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) ||
      (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) ||
      (codePoint >= 0x20D0 && codePoint <= 0x20FF) ||
      (codePoint >= 0xFE00 && codePoint <= 0xFE0F) ||
      (codePoint >= 0xFE20 && codePoint <= 0xFE2F) ||
      codePoint == 0x200D;

  bool _isWide(int codePoint) =>
      (codePoint >= 0x1100 && codePoint <= 0x115F) ||
      codePoint == 0x2329 ||
      codePoint == 0x232A ||
      (codePoint >= 0x2E80 && codePoint <= 0xA4CF) ||
      (codePoint >= 0xAC00 && codePoint <= 0xD7A3) ||
      (codePoint >= 0xF900 && codePoint <= 0xFAFF) ||
      (codePoint >= 0xFE10 && codePoint <= 0xFE19) ||
      (codePoint >= 0xFE30 && codePoint <= 0xFE6F) ||
      (codePoint >= 0xFF00 && codePoint <= 0xFF60) ||
      (codePoint >= 0xFFE0 && codePoint <= 0xFFE6) ||
      (codePoint >= 0x1F300 && codePoint <= 0x1FAFF) ||
      (codePoint >= 0x20000 && codePoint <= 0x3FFFD);

  void _lineFeed() {
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

  void _resetSequence() {
    _sequenceBuffer.clear();
    _parserState = _ParserState.ground;
  }
}
