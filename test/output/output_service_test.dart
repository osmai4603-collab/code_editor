import 'package:code_editor/core/execution/execution_controller.dart';
import 'package:code_editor/core/output/output_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ExecutionController execution;
  late OutputService output;

  setUp(() {
    execution = ExecutionController();
    output = OutputService(execution);
  });

  tearDown(() {
    output.dispose();
    execution.dispose();
  });

  test(
    'exposes execution sessions as channels without copying their lines',
    () async {
      await execution.executeCommand(command: 'echo', args: ['first output']);
      final session = execution.activeSession!;

      final channel = output.channels.single;

      expect(channel.id, session.id);
      expect(channel.source, 'Execution');
      expect(channel.session, same(session));
      expect(channel.lines, same(session.lines));
      expect(channel.lines.map((line) => line.text), contains('first output'));
      expect(output.selectedChannel?.id, channel.id);
    },
  );

  test('selects and clears only the requested channel', () async {
    await execution.executeCommand(command: 'echo', args: ['older output']);
    final olderSession = execution.activeSession!;
    await execution.executeCommand(command: 'echo', args: ['newer output']);
    final newerSession = execution.activeSession!;

    output.selectChannel(olderSession.id);
    expect(output.selectedChannel?.session, same(olderSession));

    output.clearChannel(olderSession.id);

    expect(olderSession.lines, isEmpty);
    expect(newerSession.lines, isNotEmpty);
    expect(() => output.selectChannel('unknown'), throwsArgumentError);
  });

  test('keeps bounded execution history available as channels', () async {
    for (
      var index = 0;
      index < ExecutionController.maxHistoryLength + 1;
      index++
    ) {
      await execution.executeCommand(command: 'echo', args: ['$index']);
    }

    expect(output.channels, hasLength(ExecutionController.maxHistoryLength));
    expect(output.channels.last.session, same(execution.activeSession));
  });
}
