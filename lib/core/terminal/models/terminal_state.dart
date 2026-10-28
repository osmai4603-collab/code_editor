import 'package:flutter/foundation.dart';
import '../buffer/terminal_buffer.dart';
import '../buffer/terminal_cursor.dart';
import 'terminal_color_palette.dart';
import 'terminal_style.dart';

class TerminalState extends ChangeNotifier {
  final String id;
  String title;
  String? shellType;
  String? workingDirectory;
  TerminalBuffer buffer;
  TerminalBuffer? _primaryBuffer;
  TerminalBuffer? _alternateBuffer;
  (int, int)? _primaryCursorPosition;
  (int, int)? _alternateCursorPosition;
  final TerminalCursor cursor = TerminalCursor();
  final TerminalColorPalette palette;
  TerminalStyle currentStyle = TerminalStyle.defaultStyle;
  int scrollTop = 0;
  int scrollBottom;
  bool altBuffer = false;
  bool bracketedPasteMode = false;
  bool applicationCursorKeys = false;
  bool autoWrapMode = true;
  bool insertMode = false;
  int? exitCode;
  String? errorMessage;
  bool _disposed = false;

  TerminalState({
    required this.id,
    required int cols,
    required int rows,
    this.title = 'Terminal',
    this.palette = TerminalColorPalette.dark,
    int maxScrollback = 1000,
  }) : buffer = TerminalBuffer(
         cols: cols,
         rows: rows,
         maxScrollback: maxScrollback,
       ),
       scrollBottom = rows - 1;

  void notify() {
    if (!_disposed) notifyListeners();
  }

  void reset() {
    if (altBuffer && _primaryBuffer != null) {
      buffer = _primaryBuffer!;
    }
    _primaryBuffer = null;
    _alternateBuffer = null;
    _primaryCursorPosition = null;
    _alternateCursorPosition = null;
    buffer.clear();
    cursor.moveTo(0, 0, maxRows: buffer.rows, maxCols: buffer.cols);
    currentStyle = TerminalStyle.defaultStyle;
    scrollTop = 0;
    scrollBottom = buffer.rows - 1;
    altBuffer = false;
    bracketedPasteMode = false;
    applicationCursorKeys = false;
    autoWrapMode = true;
    insertMode = false;
  }

  void enterAlternateBuffer({bool clear = true}) {
    if (altBuffer) {
      if (clear) buffer.clear();
      return;
    }
    _primaryCursorPosition = (cursor.row, cursor.col);
    _primaryBuffer = buffer;
    _alternateBuffer ??= TerminalBuffer(
      cols: buffer.cols,
      rows: buffer.rows,
      maxScrollback: 0,
    );
    _alternateBuffer!.resize(buffer.cols, buffer.rows);
    buffer = _alternateBuffer!;
    if (clear) buffer.clear();
    altBuffer = true;
    scrollTop = 0;
    scrollBottom = buffer.rows - 1;
    final alternatePosition = clear ? null : _alternateCursorPosition;
    cursor.moveTo(
      alternatePosition?.$1 ?? 0,
      alternatePosition?.$2 ?? 0,
      maxRows: buffer.rows,
      maxCols: buffer.cols,
    );
  }

  void leaveAlternateBuffer() {
    if (!altBuffer || _primaryBuffer == null) return;
    _alternateBuffer = buffer;
    _alternateCursorPosition = (cursor.row, cursor.col);
    buffer = _primaryBuffer!;
    _primaryBuffer = null;
    altBuffer = false;
    scrollTop = 0;
    scrollBottom = buffer.rows - 1;
    final primaryPosition = _primaryCursorPosition;
    _primaryCursorPosition = null;
    cursor.moveTo(
      primaryPosition?.$1 ?? 0,
      primaryPosition?.$2 ?? 0,
      maxRows: buffer.rows,
      maxCols: buffer.cols,
    );
  }

  void resize(int cols, int rows) {
    buffer.resize(cols, rows);
    _primaryBuffer?.resize(cols, rows);
    _alternateBuffer?.resize(cols, rows);
    scrollTop = 0;
    scrollBottom = buffer.rows - 1;
    cursor.moveTo(
      cursor.row,
      cursor.col,
      maxRows: buffer.rows,
      maxCols: buffer.cols,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
