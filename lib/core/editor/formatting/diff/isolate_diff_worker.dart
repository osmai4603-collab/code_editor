import 'dart:isolate';

import '../editor_text_change.dart';

class IsolateDiffWorker {
  static const _maxEditDistance = 1000;

  const IsolateDiffWorker();

  Future<List<EditorTextChange>> between(
    String oldText,
    String newText, {
    int diffLimit = 100000,
  }) async {
    if (oldText == newText) return const [];
    final eol = _lineEndingOf(oldText);
    final normalized = _normalizeLineEndings(newText, eol);
    if (oldText.length + normalized.length > diffLimit) {
      return [_wholeDocumentChange(oldText, normalized)];
    }

    final changes = await Isolate.run(
      () => _myersChanges(oldText, normalized, _maxEditDistance),
    );
    return changes ?? [_wholeDocumentChange(oldText, normalized)];
  }

  String _lineEndingOf(String text) =>
      RegExp(r'\r\n|\n|\r').firstMatch(text)?.group(0) ?? '\n';

  String _normalizeLineEndings(String text, String eol) =>
      text.replaceAll(RegExp(r'\r\n|\n|\r'), eol);
}

EditorTextChange _wholeDocumentChange(String oldText, String newText) =>
    EditorTextChange(
      start: 0,
      removedLength: oldText.length,
      insertedText: newText,
    );

List<EditorTextChange>? _myersChanges(
  String oldText,
  String newText,
  int maxEditDistance,
) {
  final oldLength = oldText.length;
  final newLength = newText.length;
  final maxDistance = oldLength + newLength;
  final furthestX = <int, int>{1: 0};
  final trace = <Map<int, int>>[];
  var distance = 0;
  var found = false;

  for (; distance <= maxDistance && distance <= maxEditDistance; distance++) {
    trace.add(Map.of(furthestX));
    for (var diagonal = -distance; diagonal <= distance; diagonal += 2) {
      var x = diagonal == -distance ||
              (diagonal != distance &&
                  (furthestX[diagonal - 1] ?? -1) <
                      (furthestX[diagonal + 1] ?? -1))
          ? furthestX[diagonal + 1] ?? 0
          : (furthestX[diagonal - 1] ?? 0) + 1;
      var y = x - diagonal;
      while (x < oldLength &&
          y < newLength &&
          oldText.codeUnitAt(x) == newText.codeUnitAt(y)) {
        x++;
        y++;
      }
      furthestX[diagonal] = x;
      if (x >= oldLength && y >= newLength) {
        found = true;
        break;
      }
    }
    if (found) break;
  }
  if (!found) return null;

  final reversedOperations = <(int, int?)>[];
  var x = oldLength;
  var y = newLength;
  for (var depth = distance; depth >= 0; depth--) {
    final previous = trace[depth];
    final diagonal = x - y;
    final previousDiagonal = diagonal == -depth ||
            (diagonal != depth &&
                (previous[diagonal - 1] ?? -1) <
                    (previous[diagonal + 1] ?? -1))
        ? diagonal + 1
        : diagonal - 1;
    final previousX = previous[previousDiagonal] ?? 0;
    final previousY = previousX - previousDiagonal;

    while (x > previousX && y > previousY) {
      reversedOperations.add((0, oldText.codeUnitAt(x - 1)));
      x--;
      y--;
    }
    if (depth == 0) break;
    if (x == previousX) {
      reversedOperations.add((1, newText.codeUnitAt(y - 1)));
      y--;
    } else {
      reversedOperations.add((-1, null));
      x--;
    }
  }

  final changes = <EditorTextChange>[];
  var oldOffset = 0;
  int? changeStart;
  var removedLength = 0;
  final inserted = StringBuffer();

  void finishChange() {
    if (changeStart == null) return;
    changes.add(
      EditorTextChange(
        start: changeStart!,
        removedLength: removedLength,
        insertedText: inserted.toString(),
      ),
    );
    changeStart = null;
    removedLength = 0;
    inserted.clear();
  }

  for (final (operation, codeUnit) in reversedOperations.reversed) {
    if (operation == 0) {
      finishChange();
      oldOffset++;
    } else if (operation == -1) {
      changeStart ??= oldOffset;
      removedLength++;
      oldOffset++;
    } else {
      changeStart ??= oldOffset;
      inserted.writeCharCode(codeUnit!);
    }
  }
  finishChange();
  return List.unmodifiable(changes);
}
