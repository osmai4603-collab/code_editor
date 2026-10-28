import 'terminal_line.dart';

class TerminalScrollback {
  final int maxLines;
  final List<TerminalLine> _lines = [];

  TerminalScrollback({this.maxLines = 1000});

  int get length => _lines.length;

  TerminalLine? operator [](int index) =>
      index >= 0 && index < _lines.length ? _lines[index] : null;

  void add(TerminalLine line) {
    if (maxLines <= 0) return;
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
  }

  void clear() => _lines.clear();

  List<TerminalLine> get lines => List.unmodifiable(_lines);
}
