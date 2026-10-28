import 'editor_indentation_options.dart';

class IndentationService {
  const IndentationService();

  EditorIndentationOptions detect(
    String text, {
    EditorIndentationOptions fallback = const _DefaultIndentationOptions(),
  }) {
    if (!fallback.detectIndentation) return fallback;

    final indentWidths = <int>[];
    var hasTabs = false;
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final prefix = RegExp(r'^[ \t]+').stringMatch(line) ?? '';
      if (prefix.isEmpty) continue;
      if (prefix.contains('\t')) {
        hasTabs = true;
      } else {
        indentWidths.add(prefix.length);
      }
    }

    if (hasTabs) {
      return fallback.copyWith(insertSpaces: false);
    }

    final levels = indentWidths.toSet().toList()..sort();
    if (levels.length < 2) return fallback;

    var size = 0;
    for (var index = 1; index < levels.length; index++) {
      final difference = levels[index] - levels[index - 1];
      size = _greatestCommonDivisor(size, difference);
    }
    if (size < 1 || size > 8) return fallback;

    return fallback.copyWith(
      tabSize: size,
      indentSize: size,
      insertSpaces: true,
    );
  }

  String indentationOf(String line) =>
      RegExp(r'^[ \t]*').stringMatch(line) ?? '';

  String convertIndentation(
    String text,
    EditorIndentationOptions options, {
    required bool toSpaces,
    int? targetIndentSize,
  }) {
    final size = targetIndentSize ?? options.tabSize;
    if (size < 1 || size > 16) {
      throw ArgumentError.value(size, 'targetIndentSize');
    }
    final lines = text.split('\n');
    return lines
        .map((line) {
          final prefix = indentationOf(line);
          if (prefix.isEmpty) return line;
          final expandedWidth = prefix
              .split('')
              .fold<int>(
                0,
                (width, character) => character == '\t'
                    ? ((width ~/ options.tabSize) + 1) * options.tabSize
                    : width + 1,
              );
          final adjustedWidth = toSpaces && targetIndentSize != null
              ? (expandedWidth ~/ options.indentSize) * targetIndentSize +
                    expandedWidth % options.indentSize
              : expandedWidth;
          final converted = toSpaces
              ? ' ' * adjustedWidth
              : '\t' * (expandedWidth ~/ size) + ' ' * (expandedWidth % size);
          return '$converted${line.substring(prefix.length)}';
        })
        .join('\n');
  }

  int _greatestCommonDivisor(int a, int b) {
    var left = a;
    var right = b;
    while (right != 0) {
      final remainder = left % right;
      left = right;
      right = remainder;
    }
    return left;
  }
}

class _DefaultIndentationOptions extends EditorIndentationOptions {
  const _DefaultIndentationOptions()
    : super(
        tabSize: 4,
        indentSize: 4,
        insertSpaces: true,
        detectIndentation: true,
      );
}
