import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the explorer facade and input formatter focused', () async {
    final controller = await File(
      'lib/core/file_system/controllers/file_explorer_controller.dart',
    ).readAsLines();
    final formatter = await File(
      'lib/core/editor/indentation/editor_input_formatter.dart',
    ).readAsLines();

    expect(controller.length, lessThan(250));
    expect(formatter.length, lessThan(220));
  });

  test('core does not import layout or feature layers', () async {
    final violations = <String>[];
    await for (final entity in Directory('lib/core').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final contents = await entity.readAsString();
      if (RegExp(
        r"""(?:package:code_editor/|['"])(?:layout|features)/""",
      ).hasMatch(contents)) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty, reason: 'Layer violations: $violations');
  });
}
