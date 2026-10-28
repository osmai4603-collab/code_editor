import 'package:flutter/services.dart';

class TerminalKeyMap {
  static final Map<LogicalKeyboardKey, String> normalMode =
      Map.unmodifiable(<LogicalKeyboardKey, String>{
        LogicalKeyboardKey.arrowUp: '\x1b[A',
        LogicalKeyboardKey.arrowDown: '\x1b[B',
        LogicalKeyboardKey.arrowRight: '\x1b[C',
        LogicalKeyboardKey.arrowLeft: '\x1b[D',
        LogicalKeyboardKey.home: '\x1b[H',
        LogicalKeyboardKey.end: '\x1b[F',
        LogicalKeyboardKey.insert: '\x1b[2~',
        LogicalKeyboardKey.delete: '\x1b[3~',
        LogicalKeyboardKey.pageUp: '\x1b[5~',
        LogicalKeyboardKey.pageDown: '\x1b[6~',
        LogicalKeyboardKey.f1: '\x1bOP',
        LogicalKeyboardKey.f2: '\x1bOQ',
        LogicalKeyboardKey.f3: '\x1bOR',
        LogicalKeyboardKey.f4: '\x1bOS',
        LogicalKeyboardKey.f5: '\x1b[15~',
        LogicalKeyboardKey.f6: '\x1b[17~',
        LogicalKeyboardKey.f7: '\x1b[18~',
        LogicalKeyboardKey.f8: '\x1b[19~',
        LogicalKeyboardKey.f9: '\x1b[20~',
        LogicalKeyboardKey.f10: '\x1b[21~',
        LogicalKeyboardKey.f11: '\x1b[23~',
        LogicalKeyboardKey.f12: '\x1b[24~',
        LogicalKeyboardKey.tab: '\t',
        LogicalKeyboardKey.escape: '\x1b',
        LogicalKeyboardKey.backspace: '\x7f',
        LogicalKeyboardKey.enter: '\r',
      });

  static final Map<LogicalKeyboardKey, String> applicationMode =
      Map.unmodifiable(<LogicalKeyboardKey, String>{
        LogicalKeyboardKey.arrowUp: '\x1bOA',
        LogicalKeyboardKey.arrowDown: '\x1bOB',
        LogicalKeyboardKey.arrowRight: '\x1bOC',
        LogicalKeyboardKey.arrowLeft: '\x1bOD',
        LogicalKeyboardKey.home: '\x1bOH',
        LogicalKeyboardKey.end: '\x1bOF',
      });

  static String? ctrlKey(String char) {
    if (char.isEmpty) return null;
    final code = char.toUpperCase().codeUnitAt(0);
    if (code >= 0x41 && code <= 0x5A) return String.fromCharCode(code - 0x40);
    return null;
  }
}
