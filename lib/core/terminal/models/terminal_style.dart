class TerminalStyle {
  final int foregroundIndex;
  final int backgroundIndex;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool dim;
  final bool inverse;
  final bool hidden;

  const TerminalStyle({
    this.foregroundIndex = -1,
    this.backgroundIndex = -1,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.dim = false,
    this.inverse = false,
    this.hidden = false,
  });

  static const defaultStyle = TerminalStyle();

  TerminalStyle copyWith({
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
    return TerminalStyle(
      foregroundIndex: foregroundIndex ?? this.foregroundIndex,
      backgroundIndex: backgroundIndex ?? this.backgroundIndex,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      dim: dim ?? this.dim,
      inverse: inverse ?? this.inverse,
      hidden: hidden ?? this.hidden,
    );
  }
}
