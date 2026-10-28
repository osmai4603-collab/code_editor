import 'package:code_editor/core/editor/formatting/editor_text_change.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds a single inserted trigger character', () {
    final change = EditorTextChange.between('value', 'value:');

    expect(change?.start, 5);
    expect(change?.removedLength, 0);
    expect(change?.insertedText, ':');
  });

  test('finds a pasted replacement range without consuming its suffix', () {
    final change = EditorTextChange.between(
      'before old after',
      'before\nnew\nafter',
    );

    expect(change?.start, 6);
    expect(change?.removedLength, 5);
    expect(change?.insertedText, '\nnew\n');
  });

  test('returns null when text did not change', () {
    expect(EditorTextChange.between('same', 'same'), isNull);
  });
}
