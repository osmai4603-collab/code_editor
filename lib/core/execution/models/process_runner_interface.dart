import '../execution_session.dart';

/// Contract for running an execution session and stopping its process.
abstract interface class IProcessRunner {
  Future<int> run({
    required ExecutionSession session,
    void Function()? onOutput,
  });

  void kill();

  bool get isRunning;
}
