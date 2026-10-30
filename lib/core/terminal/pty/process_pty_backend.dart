import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'pty_backend.dart';

class ProcessPtyBackend implements PtyBackend {
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  final StreamController<int> _exitController =
      StreamController<int>.broadcast();
  bool _disposed = false;
  bool _isRunning = false;

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
    if (_process != null) {
      throw StateError('A terminal process has already been started.');
    }
    if (_disposed) {
      throw StateError('This terminal backend has been disposed.');
    }

    final env = <String, String>{
      ...Platform.environment,
      'TERM': termType,
      'COLUMNS': '$cols',
      'LINES': '$rows',
      ...?environment,
    };
    final launch = _buildLaunchCommand(executable, args);
    final process = await Process.start(
      launch.executable,
      launch.args,
      workingDirectory: workingDirectory,
      environment: env,
      runInShell: false,
    );
    _process = process;
    _isRunning = true;
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .listen(_dataController.add, onError: _dataController.addError);
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen(_dataController.add, onError: _dataController.addError);

    unawaited(
      process.exitCode.then((code) {
        _isRunning = false;
        if (!_exitController.isClosed) _exitController.add(code);
      }),
    );
  }

  ({String executable, List<String> args}) _buildLaunchCommand(
    String executable,
    List<String> args,
  ) {
    if (!Platform.isLinux) {
      return (executable: executable, args: args);
    }

    final scriptExecutable = _findScriptExecutable();
    final command = [executable, ...args].map(_quoteShellArgument).join(' ');
    return (
      executable: scriptExecutable,
      args: ['-q', '-f', '-e', '-c', command, '/dev/null'],
    );
  }

  String _findScriptExecutable() {
    final path = Platform.environment['PATH'] ?? '';
    for (final directory in path.split(':')) {
      if (directory.isEmpty) continue;
      final candidate = '$directory${Platform.pathSeparator}script';
      if (File(candidate).existsSync()) return candidate;
    }
    throw ProcessException(
      'script',
      const [],
      'The script utility is required to provide a controlling terminal.',
    );
  }

  String _quoteShellArgument(String value) =>
      "'${value.replaceAll("'", "'\"'\"'")}'";

  @override
  void write(String data) {
    final process = _process;
    if (process == null || !_isRunning) {
      throw StateError('Cannot write to a terminal that is not running.');
    }
    process.stdin.write(data);
  }

  @override
  bool get supportsResize => false;

  @override
  void resize(int cols, int rows) {}

  @override
  void kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _process?.kill(signal);
  }

  @override
  Stream<String> get onData => _dataController.stream;

  @override
  Stream<int> get onExit => _exitController.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _process?.kill();
    unawaited(_stdoutSubscription?.cancel());
    unawaited(_stderrSubscription?.cancel());
    unawaited(_dataController.close());
    unawaited(_exitController.close());
  }
}
