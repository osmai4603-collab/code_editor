import 'package:code_editor/core/terminal/models/terminal_state.dart';
import 'package:code_editor/core/terminal/parser/ansi_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnsiParser', () {
    late TerminalState state;
    late AnsiParser parser;

    setUp(() {
      state = TerminalState(id: 'test', cols: 5, rows: 2);
      parser = AnsiParser(state);
    });

    tearDown(() {
      state.dispose();
    });

    test('writes printable text and wraps at the screen width', () {
      parser.write('hello!');

      expect(state.buffer.lines[0].toPlainText(), 'hello');
      expect(state.buffer.lines[0].isWrapped, isTrue);
      expect(state.buffer.lines[1].cells.first.character, '!');
    });

    test('parses cursor positioning and SGR across separate input chunks', () {
      parser.write('\x1b[2;3');
      parser.write('H\x1b[31mR');

      expect(state.buffer.cellAt(1, 2).character, 'R');
      expect(state.buffer.cellAt(1, 2).style.foregroundIndex, 1);
      expect(state.cursor.row, 1);
      expect(state.cursor.col, 3);
    });

    test('supports indexed and truecolor SGR values', () {
      parser.write('\x1b[38;5;201mA\x1b[48;2;1;2;3mB');

      expect(state.buffer.cellAt(0, 0).style.foregroundIndex, 201);
      expect(
        state.buffer.cellAt(0, 1).style.backgroundIndex,
        0x1000000 | (1 << 16) | (2 << 8) | 3,
      );
    });

    test('preserves the primary screen when switching to alternate screen', () {
      parser.write('base\x1b[?1049h');
      expect(state.altBuffer, isTrue);

      parser.write('alt\x1b[?1049l');

      expect(state.altBuffer, isFalse);
      expect(state.buffer.lines.first.toPlainText(), 'base ');
      expect(state.cursor.col, 4);
    });

    test(
      'restores the primary cursor after switching screens with mode 1047',
      () {
        parser.write('base\x1b[?1047halt\x1b[?1047l');

        expect(state.buffer.lines.first.toPlainText(), 'base ');
        expect(state.cursor.col, 4);
      },
    );

    test('stores wide and combining Unicode characters in display cells', () {
      parser.write('A界e\u0301');

      expect(state.buffer.cellAt(0, 0).character, 'A');
      expect(state.buffer.cellAt(0, 1).character, '界');
      expect(state.buffer.cellAt(0, 1).width, 2);
      expect(state.buffer.cellAt(0, 2).width, 0);
      expect(state.buffer.cellAt(0, 3).character, 'e\u0301');
      expect(state.cursor.col, 4);
    });

    test('erases a complete line for CSI 2 K', () {
      parser.write('abc\x1b[1;2H\x1b[2K');

      expect(state.buffer.lines.first.toPlainText(), '     ');
    });

    test('recognizes carriage return, line feed, erase, and OSC title', () {
      parser.write('abc\rZ\n\x1b[2K\x1b]2;Shell title\x07');

      expect(state.buffer.lines[0].toPlainText(), 'Zbc  ');
      expect(state.buffer.lines[1].toPlainText(), '     ');
      expect(state.cursor.row, 1);
      expect(state.title, 'Shell title');
    });
  });
}
