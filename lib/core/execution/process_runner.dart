import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'execution_session.dart';

/// مشغل العمليات المستقل (Process Runner)
///
/// ينفذ أوامر النظام والبرامج في عملية مستقلة، ويغذي جلسة التنفيذ بالمخرجات
class ProcessRunner {
  Process? _activeProcess;
  bool _isTerminated = false;

  /// إطلاق العملية وربط تدفقات الدخل والخرج بالجلسة
  Future<int> run({
    required ExecutionSession session,
    void Function()? onOutput,
  }) async {
    _isTerminated = false;
    session.addLine(
      'Executing: ${session.command} ${session.args.join(" ")}',
      OutputLineType.systemInfo,
    );
    onOutput?.call();

    try {
      final process = await Process.start(
        session.command,
        session.args,
        workingDirectory: session.workingDirectory,
        runInShell: true,
      );
      _activeProcess = process;

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        session.addLine(line, OutputLineType.stdout);
        onOutput?.call();
      });

      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        session.addLine(line, OutputLineType.stderr);
        onOutput?.call();
      });

      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);

      session.finish(exitCode, terminated: _isTerminated);
      onOutput?.call();
      _activeProcess = null;
      return exitCode;
    } catch (e) {
      session.addLine('Failed to start process: $e', OutputLineType.stderr);
      session.finish(-1);
      onOutput?.call();
      _activeProcess = null;
      return -1;
    }
  }

  /// إيقاف العملية النشطة قسراً
  void kill() {
    if (_activeProcess != null) {
      _isTerminated = true;
      _activeProcess!.kill(ProcessSignal.sigterm);
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          _activeProcess?.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });
    }
  }

  bool get isRunning => _activeProcess != null;
}
