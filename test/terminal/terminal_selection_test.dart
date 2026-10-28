import 'package:code_editor/core/terminal/buffer/terminal_buffer.dart';
import 'package:code_editor/core/terminal/models/terminal_style.dart';
import 'package:code_editor/parts/panel/views/terminal/terminal_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copies selected text from the scrolled history viewport', () {
    final buffer = TerminalBuffer(cols: 4, rows: 2);
    buffer.writeChar('A', TerminalStyle.defaultStyle, row: 0, col: 0);
    buffer.scrollUp();

    final selection = TerminalSelection()
      ..start(0, 0)
      ..update(0, 0);

    expect(selection.getSelectedText(buffer, scrollOffset: 1), 'A');
  });
}
