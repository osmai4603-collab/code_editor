import 'dart:io';

abstract interface class PtyBackend {
  Future<void> start({
    required String executable,
    List<String> args = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    required int cols,
    required int rows,
    String termType = 'xterm-256color',
  });

  void write(String data);
  bool get supportsResize => false;
  void resize(int cols, int rows);
  void kill([ProcessSignal signal = ProcessSignal.sigterm]);
  Stream<String> get onData;
  Stream<int> get onExit;
  bool get isRunning;
  void dispose();
}
