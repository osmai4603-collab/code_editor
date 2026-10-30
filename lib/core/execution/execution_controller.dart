import 'dart:io';
import 'package:flutter/foundation.dart';
import 'execution_session.dart';
import 'models/process_runner_interface.dart';
import 'process_runner.dart';
import 'resolvers/command_resolver.dart';
import 'resolvers/composite_command_resolver.dart';

/// متحكم نظام تشغيل وتنفيذ الأكواد (Execution Controller)
///
/// يدير الجلسات المفتوحة، ويربط زر Run بشاشة مخرجات اللوحة السفلية (Panel Output).
class ExecutionController extends ChangeNotifier {
  static const maxHistoryLength = 50;

  final IProcessRunner Function() _processRunnerFactory;
  final ICommandResolver _commandResolver;
  IProcessRunner? _currentRunner;
  ExecutionSession? _activeSession;
  final List<ExecutionSession> _history = [];
  int _nextSessionId = 0;

  ExecutionController({
    IProcessRunner Function()? processRunnerFactory,
    ICommandResolver? commandResolver,
  }) : _processRunnerFactory = processRunnerFactory ?? ProcessRunner.new,
       _commandResolver =
           commandResolver ??
           CompositeCommandResolver([BuiltInCommandResolver()]);

  ExecutionSession? get activeSession => _activeSession;
  List<ExecutionSession> get history => List.unmodifiable(_history);
  bool get isRunning => _currentRunner?.isRunning ?? false;

  /// تشغيل ملف برمجي استناداً إلى امتداده
  Future<int> runFile(String filePath, {String? workingDirectory}) async {
    if (isRunning) {
      stopExecution();
    }

    final plan = _commandResolver.resolve(filePath);
    return executeCommand(
      command: plan.executable,
      args: plan.arguments,
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

    final runner = _processRunnerFactory();
    _currentRunner = runner;

    try {
      return await runner.run(
        session: session,
        onOutput: () => notifyListeners(),
      );
    } finally {
      if (identical(_currentRunner, runner)) _currentRunner = null;
      notifyListeners();
    }
  }

  /// إيقاف العملية النشطة
  void stopExecution() {
    _currentRunner?.kill();
    notifyListeners();
  }

  /// مسح سجل المخرجات الحالي
  void clearOutput({ExecutionSession? session}) {
    (session ?? _activeSession)?.clearLines();
    notifyListeners();
  }
}
