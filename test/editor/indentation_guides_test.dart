import 'package:code_editor/core/editor/indentation/editor_indentation_options.dart';
import 'package:code_editor/parts/editor/widgets/indentation_guides_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draws a guide after each configured indentation level', () {
    const painter = IndentationGuidesPainter(
      indentationColumns: [],
      textStyle: TextStyle(fontFamily: 'monospace', fontSize: 14),
      options: EditorIndentationOptions(indentSize: 4, tabSize: 4),
      verticalOffset: 0,
      color: Colors.black,
    );

    expect(painter.guideColumnsForLine('    child'), isEmpty);
    expect(painter.guideColumnsForLine('        child'), [4]);
    expect(painter.guideColumnsForLine('            child'), [4, 8]);
    expect(painter.guideColumnsForLine('  child'), isEmpty);
    expect(painter.guideColumnsForLine('    '), isEmpty);
    expect(painter.guideColumnsForLine(' \t    child'), [4]);
  });

  test('uses tab stops when an indented line uses tab characters', () {
    const painter = IndentationGuidesPainter(
      indentationColumns: [],
      textStyle: TextStyle(fontFamily: 'monospace', fontSize: 14),
      options: EditorIndentationOptions(
        tabSize: 4,
        indentSize: 4,
        insertSpaces: false,
      ),
      verticalOffset: 0,
      color: Colors.black,
    );

    expect(painter.guideColumnsForLine('\t\tchild'), [4]);
  });
}
