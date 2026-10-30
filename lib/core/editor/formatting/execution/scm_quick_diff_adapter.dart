import 'dart:io';

import 'package:code_editor/core/lsp/protocol/lsp_types.dart';

class ScmQuickDiffAdapter {
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
  )
  _runProcess;

  ScmQuickDiffAdapter({
    Future<ProcessResult> Function(String executable, List<String> arguments)?
    runProcess,
  }) : _runProcess = runProcess ?? Process.run;

  Future<List<LspRange>?> modifiedRanges({
    required String workspacePath,
    required String filePath,
    required String documentText,
  }) async {
    final workspace = Directory(workspacePath).absolute.path;
    final file = File(filePath).absolute.path;
    final prefix = workspace.endsWith(Platform.pathSeparator)
        ? workspace
        : '$workspace${Platform.pathSeparator}';
    if (!file.startsWith(prefix)) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'File must be inside the workspace',
      );
    }

    final relativePath = file
        .substring(prefix.length)
        .replaceAll(Platform.pathSeparator, '/');
    final result = await _runProcess('git', [
      '-C',
      workspace,
      'diff',
      '--no-ext-diff',
      '--unified=0',
      'HEAD',
      '--',
      relativePath,
    ]);

    if (result.exitCode == 128) {
      final message = '${result.stderr}'.toLowerCase();
      if (message.contains('not a git repository') ||
          message.contains('ambiguous argument') &&
              message.contains('head') ||
          message.contains('bad revision') && message.contains('head') ||
          message.contains('unknown revision') && message.contains('head')) {
        return null;
      }
    }
    if (result.exitCode == 0) {
      final tracked = await _runProcess('git', [
        '-C',
        workspace,
        'cat-file',
        '-e',
        'HEAD:$relativePath',
      ]);
      if (tracked.exitCode != 0) return null;
    }
    if (result.exitCode != 0 && result.exitCode != 1) {
      throw ProcessException(
        'git',
        ['diff', '--unified=0', 'HEAD', '--', relativePath],
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }

    final ranges = <LspRange>[];
    final lines = documentText.split('\n');
    final hunkPattern = RegExp(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@');
    for (final line in '${result.stdout}'.split('\n')) {
      final match = hunkPattern.firstMatch(line);
      if (match == null) continue;
      final start = int.parse(match.group(1)!);
      final count = int.parse(match.group(2) ?? '1');
      if (count == 0) continue;
      final startLine = (start - 1).clamp(0, lines.length - 1).toInt();
      final endLine = startLine + count;
      final end = endLine < lines.length
          ? LspPosition(line: endLine, character: 0)
          : LspPosition(
              line: lines.length - 1,
              character: lines.last.endsWith('\r')
                  ? lines.last.length - 1
                  : lines.last.length,
            );
      ranges.add(
        LspRange(
          start: LspPosition(line: startLine, character: 0),
          end: end,
        ),
      );
    }
    return List.unmodifiable(ranges);
  }
}
