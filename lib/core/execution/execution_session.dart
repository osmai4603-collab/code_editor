/// نوع سطر مخرجات التنفيذ
enum OutputLineType {
  stdout,
  stderr,
  systemInfo,
}

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
enum ExecutionStatus {
  idle,
  running,
  completed,
  failed,
  terminatedByUser,
}

/// بيانات جلسة تشغيل برنامج حي
class ExecutionSession {
  final String id;
  final String command;
  final List<String> args;
  final String? workingDirectory;
  final DateTime startTime;
  DateTime? endTime;
  ExecutionStatus status;
  int? exitCode;
  final List<ExecutionOutputLine> lines = [];

  ExecutionSession({
    required this.id,
    required this.command,
    required this.args,
    this.workingDirectory,
  })  : startTime = DateTime.now(),
        status = ExecutionStatus.running;

  void addLine(String text, OutputLineType type) {
    lines.add(ExecutionOutputLine(
      text: text,
      type: type,
      timestamp: DateTime.now(),
    ));
  }

  void finish(int code, {bool terminated = false}) {
    endTime = DateTime.now();
    exitCode = code;
    if (terminated) {
      status = ExecutionStatus.terminatedByUser;
      addLine('Process terminated by user.', OutputLineType.systemInfo);
    } else if (code == 0) {
      status = ExecutionStatus.completed;
      addLine('Process exited successfully with code 0.', OutputLineType.systemInfo);
    } else {
      status = ExecutionStatus.failed;
      addLine('Process failed with exit code $code.', OutputLineType.systemInfo);
    }
  }
}
