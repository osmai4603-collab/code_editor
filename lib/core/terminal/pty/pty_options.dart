import 'dart:io';

class PtyOptions {
  final String executable;
  final List<String> args;
  final String? workingDirectory;
  final Map<String, String> environment;
  final int cols;
  final int rows;
  final String termType;

  const PtyOptions({
    required this.executable,
    this.args = const [],
    this.workingDirectory,
    this.environment = const {},
    this.cols = 80,
    this.rows = 24,
    this.termType = 'xterm-256color',
  });

  static String get defaultShell {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    }
    return Platform.environment['SHELL'] ??
        (Platform.isMacOS ? '/bin/zsh' : '/bin/bash');
  }

  static List<String> get defaultShellArgs =>
      Platform.isLinux ? const ['-i'] : const [];
}
