import 'dart:io';
import 'package:flutter/foundation.dart';
import 'execution_session.dart';
import 'process_runner.dart';

/// متحكم نظام تشغيل وتنفيذ الأكواد (Execution Controller)
///
/// يدير الجلسات المفتوحة، ويربط زر Run بشاشة مخرجات اللوحة السفلية (Panel Output).
class ExecutionController extends ChangeNotifier {
  static const maxHistoryLength = 50;

  ProcessRunner? _currentRunner;
  ExecutionSession? _activeSession;
  final List<ExecutionSession> _history = [];
  int _nextSessionId = 0;

  ExecutionSession? get activeSession => _activeSession;
  List<ExecutionSession> get history => List.unmodifiable(_history);
  bool get isRunning => _currentRunner?.isRunning ?? false;

  /// تشغيل ملف برمجي استناداً إلى امتداده
  Future<int> runFile(String filePath, {String? workingDirectory}) async {
    if (isRunning) {
      stopExecution();
    }

    final executableAndArgs = _resolveCommandForFile(filePath);
    return executeCommand(
      command: executableAndArgs.first,
      args: executableAndArgs.sublist(1),
      workingDirectory: workingDirectory ?? File(filePath).parent.path,
    );
  }

  /// إطلاق أمر عام
  Future<int> executeCommand({
    required String command,
    required List<String> args,
    String? workingDirectory,
  }) async {
    if (isRunning) {
      stopExecution();
    }

    final session = ExecutionSession(
      id: 'execution_${DateTime.now().microsecondsSinceEpoch}_${_nextSessionId++}',
      command: command,
      args: args,
      workingDirectory: workingDirectory,
    );

    _activeSession = session;
    _history.add(session);
    if (_history.length > maxHistoryLength) {
      _history.removeRange(0, _history.length - maxHistoryLength);
    }
    notifyListeners();

    final runner = ProcessRunner();
    _currentRunner = runner;

    final code = await runner.run(
      session: session,
      onOutput: () => notifyListeners(),
    );

    _currentRunner = null;
    notifyListeners();
    return code;
  }

  /// إيقاف العملية النشطة
  void stopExecution() {
    _currentRunner?.kill();
    notifyListeners();
  }

  /// مسح سجل المخرجات الحالي
  void clearOutput({ExecutionSession? session}) {
    (session ?? _activeSession)?.lines.clear();
    notifyListeners();
  }

  List<String> _resolveCommandForFile(String filePath) {
    if (filePath.endsWith('.dart')) {
      const knownDart = '/home/osm/.development/flutter/bin/dart';
      final cmd = File(knownDart).existsSync() ? knownDart : 'dart';
      return [cmd, 'run', filePath];
    } else if (filePath.endsWith('.py')) {
      return ['python3', filePath];
    } else if (filePath.endsWith('.sh')) {
      return ['bash', filePath];
    } else if (filePath.endsWith('.js')) {
      return ['node', filePath];
    }
    return ['cat', filePath];
  }
}
