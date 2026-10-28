import 'dart:collection';

/// نوع سطر مخرجات التنفيذ
enum OutputLineType { stdout, stderr, systemInfo }

/// سطر مفرد في سجل مخرجات التنفيذ مع توقيته ونوعه
class ExecutionOutputLine {
  final String text;
  final OutputLineType type;
  final DateTime timestamp;

  const ExecutionOutputLine({
    required this.text,
    required this.type,
    required this.timestamp,
  });
}

/// حالة جلسة التنفيذ
enum ExecutionStatus { idle, running, completed, failed, terminatedByUser }

/// بيانات جلسة تشغيل برنامج حي
class ExecutionSession {
  static const maxOutputLines = 5000;

  final String id;
  final String command;
  final List<String> args;
  final String? workingDirectory;
  final DateTime startTime;
  DateTime? endTime;
  ExecutionStatus status;
  int? exitCode;
  final Queue<ExecutionOutputLine> _lines = Queue();
  List<ExecutionOutputLine>? _lineSnapshot;

  List<ExecutionOutputLine> get lines =>
      _lineSnapshot ??= List.unmodifiable(_lines);

  ExecutionSession({
    required this.id,
    required this.command,
    required this.args,
    this.workingDirectory,
  }) : startTime = DateTime.now(),
       status = ExecutionStatus.running;

  void addLine(String text, OutputLineType type) {
    _lines.addLast(
      ExecutionOutputLine(text: text, type: type, timestamp: DateTime.now()),
    );
    if (_lines.length > maxOutputLines) _lines.removeFirst();
    _lineSnapshot = null;
  }

  void clearLines() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _lineSnapshot = null;
  }

  void finish(int code, {bool terminated = false}) {
    endTime = DateTime.now();
    exitCode = code;
    if (terminated) {
      status = ExecutionStatus.terminatedByUser;
      addLine('Process terminated by user.', OutputLineType.systemInfo);
    } else if (code == 0) {
      status = ExecutionStatus.completed;
      addLine(
        'Process exited successfully with code 0.',
        OutputLineType.systemInfo,
      );
    } else {
      status = ExecutionStatus.failed;
      addLine(
        'Process failed with exit code $code.',
        OutputLineType.systemInfo,
      );
    }
  }
}
