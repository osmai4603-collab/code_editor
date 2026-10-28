import '../models/terminal_state.dart';

class OscHandler {
  final TerminalState _state;

  OscHandler(this._state);

  void handle(String data) {
    final separator = data.indexOf(';');
    if (separator < 0) return;
    final command = int.tryParse(data.substring(0, separator));
    final value = data.substring(separator + 1);
    switch (command) {
      case 0:
      case 2:
        _state.title = value;
      case 7:
        final uri = Uri.tryParse(value);
        if (uri != null && uri.scheme == 'file') {
          _state.workingDirectory = uri.toFilePath();
        }
    }
  }
}
