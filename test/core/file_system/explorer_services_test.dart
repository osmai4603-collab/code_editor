import 'dart:io';

import 'package:code_editor/core/file_system/services/explorer_persistence_store.dart';
import 'package:code_editor/core/file_system/services/git_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Git porcelain status into workspace paths', () async {
    final service = ProcessGitStatusService(
      runProcess: (executable, arguments) async => ProcessResult(
        1,
        0,
        ' M lib/main.dart\u0000?? new.txt\u0000',
        '',
      ),
    );

    final statuses = await service.refreshStatus('/workspace');

    expect(statuses['/workspace/lib${Platform.pathSeparator}main.dart'], 'M');
    expect(statuses['/workspace${Platform.pathSeparator}new.txt'], 'U');
  });

  test('persists expanded paths and selected path per workspace', () async {
    final directory = await Directory.systemTemp.createTemp(
      'explorer-state-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonExplorerPersistenceStore(
      stateFile: File('${directory.path}/state.json'),
    );

    await store.save(
      ExplorerPersistedState(
        workspacePath: '/workspace',
        expandedPaths: {'/workspace', '/workspace/lib'},
        selectedPath: '/workspace/lib/main.dart',
      ),
    );

    final restored = await store.load('/workspace');
    expect(restored?.expandedPaths, {'/workspace', '/workspace/lib'});
    expect(restored?.selectedPath, '/workspace/lib/main.dart');
    expect(await store.load('/another-workspace'), isNull);
  });
}
