import 'package:code_editor/core/terminal/buffer/terminal_buffer.dart';
import 'package:code_editor/core/terminal/models/terminal_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TerminalBuffer', () {
    test('initializes a screen with the requested bounded size', () {
      final buffer = TerminalBuffer(cols: 8, rows: 3);

      expect(buffer.cols, 8);
      expect(buffer.rows, 3);
      expect(buffer.lines, hasLength(3));
      expect(buffer.cellAt(0, 0).character, ' ');
    });

    test('scrolls full-screen lines into bounded scrollback', () {
      final buffer = TerminalBuffer(cols: 4, rows: 2, maxScrollback: 1);
      buffer.writeChar('A', TerminalStyle.defaultStyle, row: 0, col: 0);
      buffer.scrollUp();
      buffer.writeChar('B', TerminalStyle.defaultStyle, row: 0, col: 0);
      buffer.scrollUp();

      expect(buffer.scrollbackLength, 1);
      expect(buffer.scrollbackLine(0)!.cells.first.character, 'B');
      expect(buffer.lines, hasLength(2));
    });

    test('resizes rows and columns while preserving existing cells', () {
      final buffer = TerminalBuffer(cols: 4, rows: 2);
      buffer.writeChar('x', TerminalStyle.defaultStyle, row: 0, col: 0);

      buffer.resize(6, 3);

      expect(buffer.cols, 6);
      expect(buffer.rows, 3);
      expect(buffer.cellAt(0, 0).character, 'x');
      expect(buffer.cellAt(2, 5).character, ' ');
    });
  });
}
