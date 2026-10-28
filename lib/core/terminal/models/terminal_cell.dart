import 'terminal_style.dart';

class TerminalCell {
  String character;
  TerminalStyle style;
  int width;

  TerminalCell({
    this.character = ' ',
    this.style = TerminalStyle.defaultStyle,
    this.width = 1,
  });

  factory TerminalCell.empty([
    TerminalStyle style = TerminalStyle.defaultStyle,
  ]) => TerminalCell(style: style);

  TerminalCell copy() =>
      TerminalCell(character: character, style: style, width: width);
}
