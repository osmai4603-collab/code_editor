import 'package:code_editor/core/editor/highlighting/editor_highlight_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = EditorHighlightService();

  group('matching bracket highlights', () {
    test(
      'matches nested pairs when the cursor is before or after a bracket',
      () {
        const text = 'call([value])';
        expect(
          service.matchingBracketOffsets('/workspace/file.dart', text, 4),
          {4, 12},
        );
        expect(
          service.matchingBracketOffsets('/workspace/file.dart', text, 13),
          {4, 12},
        );
        expect(
          service.matchingBracketOffsets('/workspace/file.dart', text, 6),
          {5, 11},
        );
      },
    );

    test('does not match brackets inside comments or strings', () {
      const text = 'final value = "("; // [\nfinal other = 1;';
      expect(
        service.matchingBracketOffsets('/workspace/file.dart', text, 16),
        isEmpty,
      );
      expect(
        service.matchingBracketOffsets('/workspace/file.dart', text, 23),
        isEmpty,
      );
    });
  });

  group('matching word highlights', () {
    test(
      'finds whole-word matches when the cursor is inside or at the end',
      () {
        const text = 'count counter count';
        expect(service.matchingWordRanges(text, 2), [(0, 5), (14, 19)]);
        expect(service.matchingWordRanges(text, 5), [(0, 5), (14, 19)]);
      },
    );

    test(
      'highlights single-character words and excludes partial identifiers',
      () {
        expect(service.matchingWordRanges('x xx x', 0), [(0, 1), (5, 6)]);
        expect(service.matchingWordRanges('foo food', 1), isEmpty);
      },
    );
  });
}
