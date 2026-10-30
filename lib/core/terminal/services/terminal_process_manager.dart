import 'dart:async';
import 'dart:collection';
import 'dart:io';
import '../models/terminal_state.dart';
import '../parser/ansi_parser.dart';
import '../pty/process_pty_backend.dart';
import '../pty/pty_backend.dart';
import '../pty/pty_options.dart';
import 'flow_control.dart';

class TerminalProcessManager {
  final TerminalState state;
  final PtyBackend _backend;
  late final AnsiParser _parser = AnsiParser(state);
  final FlowController _flowControl = FlowController();
  final Queue<String> _pendingData = Queue<String>();
  StreamSubscription<String>? _dataSub;
  StreamSubscription<int>? _exitSub;
  bool _disposed = false;
  bool _started = false;
  bool _processingScheduled = false;

  TerminalProcessManager({required this.state, PtyBackend? backend})
    : _backend = backend ?? ProcessPtyBackend();

  bool get isRunning => _backend.isRunning;

  Future<void> start([PtyOptions? options]) async {
    if (_disposed) {
      throw StateError('This terminal manager has been disposed.');
    }
    if (_started) {
      throw StateError('This terminal manager has already started.');
    }
    _started = true;
    final opts =
        options ??
        PtyOptions(
          executable: PtyOptions.defaultShell,
          args: PtyOptions.defaultShellArgs,
          workingDirectory: Directory.current.path,
          cols: state.buffer.cols,
          rows: state.buffer.rows,
        );

    try {
      _dataSub = _backend.onData.listen(
        _onDataReceived,
        onError: (Object error, StackTrace stackTrace) {
          state.errorMessage = 'Terminal output error: $error';
          state.notify();
        },
      );
      _exitSub = _backend.onExit.listen(_onProcessExit);
      state.workingDirectory = opts.workingDirectory;
      state.shellType = opts.executable.split(Platform.pathSeparator).last;
      await _backend.start(
        executable: opts.executable,
        args: opts.args,
        workingDirectory: opts.workingDirectory,
        environment: opts.environment,
        cols: opts.cols,
        rows: opts.rows,
        termType: opts.termType,
      );
    } catch (_) {
      await _dataSub?.cancel();
      await _exitSub?.cancel();
      _dataSub = null;
      _exitSub = null;
      _started = false;
      rethrow;
    }
  }

  void _onDataReceived(String data) {
    if (_disposed) return;
    _pendingData.addLast(data);
    if (_flowControl.shouldPause(data.length)) {
      _dataSub?.pause();
    }
    _schedulePendingData();
  }

  void _schedulePendingData() {
    if (_processingScheduled || _pendingData.isEmpty || _disposed) return;
    _processingScheduled = true;
    scheduleMicrotask(_processNextDataChunk);
  }

  void _processNextDataChunk() {
    _processingScheduled = false;
    if (_disposed || _pendingData.isEmpty) return;
    final data = _pendingData.removeFirst();
    try {
      _parser.write(data);
    } catch (error) {
      state.errorMessage = 'Terminal parsing error: $error';
      state.notify();
    } finally {
      _flowControl.acknowledge(data.length);
      if (_dataSub?.isPaused == true && !_flowControl.isPaused) {
        _dataSub!.resume();
      }
      _schedulePendingData();
    }
  }

  void _onProcessExit(int exitCode) {
    state.exitCode = exitCode;
    state.title = '${state.title} [exited: $exitCode]';
    state.notify();
  }

  void sendInput(String data) => _backend.write(data);

  void resize(int cols, int rows) {
    final safeCols = cols.clamp(1, 500).toInt();
    final safeRows = rows.clamp(1, 200).toInt();
    state.resize(safeCols, safeRows);
    if (_backend.supportsResize) {
      _backend.resize(safeCols, safeRows);
    }
    state.notify();
  }

  void kill() => _backend.kill();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_dataSub?.cancel());
    unawaited(_exitSub?.cancel());
    _pendingData.clear();
    _backend.dispose();
  }
}
