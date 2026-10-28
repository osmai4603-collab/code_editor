import 'dart:async';
import 'dart:io';

import 'package:code_editor/core/terminal/models/terminal_state.dart';
import 'package:code_editor/core/terminal/pty/pty_backend.dart';
import 'package:code_editor/core/terminal/pty/pty_options.dart';
import 'package:code_editor/core/terminal/services/terminal_process_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePtyBackend implements PtyBackend {
  final StreamController<String> _data = StreamController<String>.broadcast();
  final StreamController<int> _exit = StreamController<int>.broadcast();
  final List<String> writes = [];
  int? resizedCols;
  int? resizedRows;
  bool _isRunning = false;

  @override
  Stream<String> get onData => _data.stream;

  @override
  Stream<int> get onExit => _exit.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start({
    required String executable,
    List<String> args = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    required int cols,
    required int rows,
    String termType = 'xterm-256color',
  }) async {
    _isRunning = true;
  }

  @override
  void write(String data) => writes.add(data);

  @override
  void resize(int cols, int rows) {
    resizedCols = cols;
    resizedRows = rows;
  }

  @override
  void kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _isRunning = false;
  }

  @override
  void dispose() {
    _isRunning = false;
    unawaited(_data.close());
    unawaited(_exit.close());
  }
}

void main() {
  test(
    'connects process output, input, exit, and resize to terminal state',
    () async {
      final state = TerminalState(id: 'test', cols: 5, rows: 2);
      final backend = _FakePtyBackend();
      final manager = TerminalProcessManager(state: state, backend: backend);

      await manager.start(
        const PtyOptions(executable: 'fake-shell', cols: 5, rows: 2),
      );
      backend._data.add('hello');
      await Future<void>.delayed(Duration.zero);

      expect(state.buffer.lines.first.toPlainText(), 'hello');

      manager.sendInput('command\r');
      expect(backend.writes, ['command\r']);

      manager.resize(600, 250);
      expect(state.buffer.cols, 500);
      expect(state.buffer.rows, 200);
      expect(backend.resizedCols, 500);
      expect(backend.resizedRows, 200);

      backend._exit.add(7);
      await Future<void>.delayed(Duration.zero);
      expect(state.exitCode, 7);
      expect(state.title, 'Terminal [exited: 7]');

      manager.dispose();
      state.dispose();
    },
  );
}
