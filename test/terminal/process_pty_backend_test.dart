import 'dart:async';
import 'dart:io';

import 'package:code_editor/core/terminal/pty/process_pty_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'forwards interactive process input, output, and exit status',
    () async {
      final backend = ProcessPtyBackend();
      final output = StringBuffer();
      final outputReceived = Completer<void>();
      final outputSubscription = backend.onData.listen((data) {
        output.write(data);
        if (output.toString().contains('terminal-ok') &&
            !outputReceived.isCompleted) {
          outputReceived.complete();
        }
      });
      final exitCode = backend.onExit.first;

      try {
        await backend.start(executable: '/bin/sh', cols: 80, rows: 24);
        backend.write('printf "terminal-ok\\n"; exit 0\n');

        await outputReceived.future.timeout(const Duration(seconds: 5));
        expect(output.toString(), contains('terminal-ok'));
        expect(await exitCode.timeout(const Duration(seconds: 5)), 0);
      } finally {
        await outputSubscription.cancel();
        backend.dispose();
      }
    },
    skip: Platform.isWindows || !File('/bin/sh').existsSync(),
  );

  test(
    'starts interactive Bash with a controlling terminal and no job-control warnings',
    () async {
      final backend = ProcessPtyBackend();
      final output = StringBuffer();
      final ready = Completer<void>();
      final outputSubscription = backend.onData.listen((data) {
        output.write(data);
        if (output.toString().contains('PTY_READY') && !ready.isCompleted) {
          ready.complete();
        }
      });
      final exitCode = backend.onExit.first;

      try {
        await backend.start(
          executable: '/bin/bash',
          args: const ['-i'],
          cols: 80,
          rows: 24,
        );
        backend.write('printf "PTY_READY\\n"\n');

        await ready.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('PTY output: $output'),
        );
        backend.write('exit\n');
        expect(await exitCode.timeout(const Duration(seconds: 5)), 0);
        expect(output.toString(), contains('PTY_READY'));
        expect(
          output.toString(),
          isNot(contains('cannot set terminal process group')),
        );
        expect(output.toString(), isNot(contains('no job control')));
      } finally {
        await outputSubscription.cancel();
        backend.dispose();
      }
    },
    skip:
        !Platform.isLinux ||
        !File('/bin/bash').existsSync() ||
        !File('/usr/bin/script').existsSync(),
  );
}
