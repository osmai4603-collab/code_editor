import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/terminal_state.dart';
import '../services/terminal_process_manager.dart';
import 'terminal_key_map.dart';

class TerminalInputHandler {
  final TerminalProcessManager _processManager;
  final TerminalState _state;

  TerminalInputHandler({required this._processManager, required this._state});

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_processManager.isRunning) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final hardware = HardwareKeyboard.instance;
    final isCtrl = hardware.isControlPressed || hardware.isMetaPressed;
    final isAlt = hardware.isAltPressed;
    final isShift = hardware.isShiftPressed;

    if (isCtrl && !isAlt) {
      if (key == LogicalKeyboardKey.keyC ||
          key == LogicalKeyboardKey.keyD ||
          key == LogicalKeyboardKey.keyZ) {
        final control = switch (key) {
          LogicalKeyboardKey.keyC => '\x03',
          LogicalKeyboardKey.keyD => '\x04',
          _ => '\x1a',
        };
        _processManager.sendInput(control);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) return KeyEventResult.ignored;
      final character = event.character;
      if (character != null) {
        final control = TerminalKeyMap.ctrlKey(character);
        if (control != null) {
          _processManager.sendInput(control);
          return KeyEventResult.handled;
        }
      }
    }

    if (isAlt && !isCtrl) {
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        _processManager.sendInput('\x1b$character');
        return KeyEventResult.handled;
      }
    }

    final keyMap = _state.applicationCursorKeys
        ? TerminalKeyMap.applicationMode
        : TerminalKeyMap.normalMode;
    final sequence = keyMap[key];
    if (sequence != null) {
      _processManager.sendInput(
        _addModifier(sequence, isShift: isShift, isCtrl: isCtrl, isAlt: isAlt),
      );
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.isNotEmpty && !isCtrl) {
      _processManager.sendInput(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _addModifier(
    String sequence, {
    required bool isShift,
    required bool isCtrl,
    required bool isAlt,
  }) {
    final modifier = 1 + (isShift ? 1 : 0) + (isAlt ? 2 : 0) + (isCtrl ? 4 : 0);
    if (modifier == 1) return sequence;
    if (sequence.startsWith('\x1b[') && sequence.length == 3) {
      return '\x1b[1;$modifier${sequence[2]}';
    }
    return sequence;
  }
}
