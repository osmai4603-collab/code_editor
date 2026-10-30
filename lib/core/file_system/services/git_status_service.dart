import 'dart:io';

/// Reads Git status for a workspace without coupling it to the explorer UI.
abstract interface class IGitStatusService {
  Future<Map<String, String>> refreshStatus(String rootPath);
}

/// Loads changed paths by invoking `git status --porcelain`.
class ProcessGitStatusService implements IGitStatusService {
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
  )
  _runProcess;

  ProcessGitStatusService({
    Future<ProcessResult> Function(String executable, List<String> arguments)?
    runProcess,
  }) : _runProcess = runProcess ?? _run;

  static Future<ProcessResult> _run(
    String executable,
    List<String> arguments,
  ) => Process.run(executable, arguments);

  @override
  Future<Map<String, String>> refreshStatus(String rootPath) async {
    final result = await _runProcess('git', [
      '-C',
      rootPath,
      '-c',
      'core.quotepath=false',
      'status',
      '--porcelain=v1',
      '-z',
      '--untracked-files=all',
    ]);
    if (result.exitCode != 0) {
      final message = '${result.stderr}'.trim();
      if (message.toLowerCase().contains('not a git repository')) {
        return const {};
      }
      throw ProcessException(
        'git',
        ['status', '--porcelain=v1'],
        message,
        result.exitCode,
      );
    }

    final statuses = <String, String>{};
    final entries = '${result.stdout}'.split('\u0000');
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.length < 4) continue;
      final state = entry.substring(0, 2);
      final path = entry.substring(3);
      final status = state.contains('D')
          ? 'D'
          : state.contains('A')
          ? 'A'
          : state.contains('R')
          ? 'R'
          : state.contains('M')
          ? 'M'
          : state.contains('?')
          ? 'U'
          : '';
      if (status.isNotEmpty) {
        statuses[_join(rootPath, path.replaceAll('/', Platform.pathSeparator))] =
            status;
      }
      if (state.contains('R') || state.contains('C')) {
        index++;
      }
    }
    return Map.unmodifiable(statuses);
  }

  static String _join(String directory, String name) =>
      directory.endsWith(Platform.pathSeparator)
      ? '$directory$name'
      : '$directory${Platform.pathSeparator}$name';
}
