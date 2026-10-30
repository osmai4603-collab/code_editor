import 'package:code_editor/core/execution/resolvers/command_resolver.dart';
import 'package:code_editor/core/execution/resolvers/composite_command_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExtensionResolver implements ICommandResolver {
  @override
  bool canResolve(String filePath) => filePath.endsWith('.custom');

  @override
  ExecutionPlan resolve(String filePath) =>
      ExecutionPlan(executable: 'custom-runner', arguments: [filePath]);
}

void main() {
  group('CompositeCommandResolver', () {
    test('resolves built-in file types', () {
      final resolver = CompositeCommandResolver([BuiltInCommandResolver()]);

      expect(resolver.resolve('main.py').executable, 'python3');
      expect(resolver.resolve('main.js').executable, 'node');
      expect(resolver.resolve('notes.txt').executable, 'cat');
    });

    test('allows a registered strategy to override defaults', () {
      final resolver = CompositeCommandResolver([BuiltInCommandResolver()])
        ..registerResolver(_ExtensionResolver());

      final plan = resolver.resolve('source.custom');

      expect(plan.executable, 'custom-runner');
      expect(plan.arguments, ['source.custom']);
    });
  });
}
