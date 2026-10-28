import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/breadcrumbs/models/breadcrumb_path_entry.dart';
import 'package:code_editor/core/breadcrumbs/services/breadcrumbs_path_service.dart';

void main() {
  const service = BreadcrumbsPathService();

  group('BreadcrumbsPathService', () {
    test('shows a workspace-relative path without its absolute prefix', () {
      final path = service.buildPath(
        filePath: '/private/users/alice/project/lib/main.dart',
        workspacePath: '/private/users/alice/project',
      );

      expect(path.map((entry) => entry.label), ['project', 'lib', 'main.dart']);
      expect(path.first.path, '/private/users/alice/project');
      expect(path.last.directoryPath, '/private/users/alice/project/lib');
    });

    test('normalizes dot segments and avoids duplicate separators', () {
      final path = service.buildPath(
        filePath: '/workspace//lib/./src/../main.dart',
        workspacePath: '/workspace/',
      );

      expect(path.map((entry) => entry.label), [
        'workspace',
        'lib',
        'main.dart',
      ]);
    });

    test('returns only the workspace entry for its root path', () {
      final path = service.buildPath(
        filePath: '/workspace',
        workspacePath: '/workspace',
      );

      expect(path, hasLength(1));
      expect(path.single.kind, BreadcrumbPathEntryKind.workspace);
    });

    test('keeps a filesystem root as one non-empty breadcrumb', () {
      final path = service.buildPath(filePath: '/');

      expect(path, hasLength(1));
      expect(path.single.label, '/');
      expect(path.single.kind, BreadcrumbPathEntryKind.root);
    });

    test('shows an external absolute file path from its filesystem root', () {
      final path = service.buildPath(
        filePath: '/other/src/main.dart',
        workspacePath: '/workspace',
      );

      expect(path.map((entry) => entry.label), [
        '/',
        'other',
        'src',
        'main.dart',
      ]);
      expect(path.first.kind, BreadcrumbPathEntryKind.root);
    });

    test(
      'handles Windows drive paths and case-insensitive workspace matching',
      () {
        final path = service.buildPath(
          filePath: r'c:\PROJECT\lib\main.dart',
          workspacePath: r'C:\project',
        );

        expect(path.map((entry) => entry.label), [
          'project',
          'lib',
          'main.dart',
        ]);
        expect(path[1].path, r'C:\project\lib');
        expect(path.last.path, r'C:\project\lib\main.dart');
      },
    );

    test('resolves a relative file path against a workspace', () {
      final path = service.buildPath(
        filePath: 'lib/main.dart',
        workspacePath: '/workspace',
      );

      expect(path.map((entry) => entry.label), [
        'workspace',
        'lib',
        'main.dart',
      ]);
    });

    test(
      'does not treat a relative path escaping the workspace as internal',
      () {
        final path = service.buildPath(
          filePath: '../outside/main.dart',
          workspacePath: '/workspace',
        );

        expect(path.map((entry) => entry.label), ['/', 'outside', 'main.dart']);
      },
    );

    test(
      'does not render an empty path or a file URI as filesystem segments',
      () {
        expect(service.buildPath(filePath: ''), isEmpty);
        expect(
          service.buildPath(filePath: 'file:///workspace/file.dart'),
          isEmpty,
        );
      },
    );
  });
}
