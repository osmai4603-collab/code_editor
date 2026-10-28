import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/execution/execution_session.dart';

void main() {
  group('Execution Subsystem Tests', () {
    late ExecutionController controller;

    setUp(() {
      controller = ExecutionController();
    });

    tearDown(() {
      controller.stopExecution();
      controller.dispose();
    });

    test(
      'Executes a shell command and captures stdout and exit code 0',
      () async {
        final code = await controller.executeCommand(
          command: 'echo',
          args: ['مرحباً بك في محرك تشغيل الأكواد'],
        );

        expect(code, equals(0));
        expect(controller.activeSession, isNotNull);
        final session = controller.activeSession!;
        expect(session.status, equals(ExecutionStatus.completed));
        expect(session.exitCode, equals(0));
        expect(
          session.lines.any(
            (l) => l.text.contains('مرحباً بك في محرك تشغيل الأكواد'),
          ),
          isTrue,
        );
      },
    );

    test(
      'Captures stderr when a command fails with non-zero exit code',
      () async {
        final code = await controller.executeCommand(
          command: 'bash',
          args: ['-c', 'echo "خطأ برمجي تجريبي" >&2; exit 2'],
        );

        expect(code, equals(2));
        final session = controller.activeSession!;
        expect(session.status, equals(ExecutionStatus.failed));
        expect(session.exitCode, equals(2));
        expect(
          session.lines.any(
            (l) =>
                l.type == OutputLineType.stderr &&
                l.text.contains('خطأ برمجي تجريبي'),
          ),
          isTrue,
        );
      },
    );

    test('Can terminate running process via stopExecution', () async {
      final future = controller.executeCommand(command: 'sleep', args: ['5']);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.isRunning, isTrue);

      controller.stopExecution();
      await future;

      final session = controller.activeSession!;
      expect(session.status, equals(ExecutionStatus.terminatedByUser));
    });

    test('Bounds output retained by an execution session', () {
      final session = ExecutionSession(
        id: 'bounded',
        command: 'test',
        args: [],
      );

      for (var index = 0; index <= ExecutionSession.maxOutputLines; index++) {
        session.addLine('$index', OutputLineType.stdout);
      }

      expect(session.lines, hasLength(ExecutionSession.maxOutputLines));
      expect(session.lines.first.text, '1');
      expect(session.lines.last.text, '${ExecutionSession.maxOutputLines}');
    });

    test('Clears output for the selected historical session', () async {
      await controller.executeCommand(command: 'echo', args: ['first']);
      final first = controller.activeSession!;
      await controller.executeCommand(command: 'echo', args: ['second']);
      final second = controller.activeSession!;

      controller.clearOutput(session: first);

      expect(first.lines, isEmpty);
      expect(second.lines, isNotEmpty);
    });
  });
}
