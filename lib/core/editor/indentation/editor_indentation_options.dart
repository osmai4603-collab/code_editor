class EditorIndentationOptions {
  final int tabSize;
  final int indentSize;
  final bool insertSpaces;
  final bool detectIndentation;

  const EditorIndentationOptions({
    this.tabSize = 4,
    this.indentSize = 4,
    this.insertSpaces = true,
    this.detectIndentation = true,
  }) : assert(tabSize >= 1 && tabSize <= 16),
       assert(indentSize >= 1 && indentSize <= 16);

  String get indentUnit => insertSpaces ? ' ' * indentSize : '\t';

  EditorIndentationOptions copyWith({
    int? tabSize,
    int? indentSize,
    bool? insertSpaces,
    bool? detectIndentation,
  }) {
    return EditorIndentationOptions(
      tabSize: tabSize ?? this.tabSize,
      indentSize: indentSize ?? this.indentSize,
      insertSpaces: insertSpaces ?? this.insertSpaces,
      detectIndentation: detectIndentation ?? this.detectIndentation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditorIndentationOptions &&
      tabSize == other.tabSize &&
      indentSize == other.indentSize &&
      insertSpaces == other.insertSpaces &&
      detectIndentation == other.detectIndentation;

  @override
  int get hashCode =>
      Object.hash(tabSize, indentSize, insertSpaces, detectIndentation);
}
