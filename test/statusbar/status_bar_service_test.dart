import 'package:code_editor/core/statusbar/models/status_bar_alignment.dart';
import 'package:code_editor/core/statusbar/models/status_bar_entry.dart';
import 'package:code_editor/core/statusbar/status_bar_preferences_store.dart';
import 'package:code_editor/core/statusbar/status_bar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StatusBarEntry entry(
    String id, {
    StatusBarAlignment alignment = StatusBarAlignment.left,
    int priority = 0,
    String? text,
  }) {
    return StatusBarEntry(
      id: id,
      name: id,
      text: text ?? id,
      alignment: alignment,
      priority: priority,
    );
  }

  test('sorts by alignment, priority, then stable insertion order', () async {
    final service = StatusBarService(
      preferencesStore: InMemoryStatusBarPreferencesStore(),
    );
    await service.initialize();
    service
      ..addEntry(entry('left-first', priority: 2))
      ..addEntry(
        entry('right', alignment: StatusBarAlignment.right, priority: 9),
      )
      ..addEntry(entry('left-second', priority: 2))
      ..addEntry(entry('left-high', priority: 3));

    expect(service.entries.map((entry) => entry.id), [
      'left-high',
      'left-first',
      'left-second',
      'right',
    ]);
    expect(() => service.entries.clear(), throwsUnsupportedError);
    service.dispose();
  });

  test(
    'updates entries without changing identity or insertion order',
    () async {
      final service = StatusBarService(
        preferencesStore: InMemoryStatusBarPreferencesStore(),
      );
      await service.initialize();
      final first = service.addEntry(entry('first', priority: 5));
      service.addEntry(entry('second', priority: 5));

      first.update(entry('first', priority: 5, text: 'updated'));
      expect(service.entries.map((entry) => entry.text), ['updated', 'second']);
      expect(() => first.update(entry('other')), throwsArgumentError);

      first.dispose();
      first.dispose();
      expect(service.entries.map((entry) => entry.id), ['second']);
      service.dispose();
    },
  );

  test(
    'rejects duplicate IDs and supports entries before listeners attach',
    () async {
      final service = StatusBarService(
        preferencesStore: InMemoryStatusBarPreferencesStore(),
      );
      await service.initialize();
      service.addEntry(entry('existing'));

      expect(() => service.addEntry(entry('existing')), throwsArgumentError);
      expect(service.entries.single.id, 'existing');
      service.dispose();
    },
  );

  test('rejects empty identities and display names', () async {
    final service = StatusBarService(
      preferencesStore: InMemoryStatusBarPreferencesStore(),
    );
    await service.initialize();

    expect(() => service.addEntry(entry('  ')), throwsArgumentError);
    expect(
      () => service.addEntry(
        const StatusBarEntry(
          id: 'valid-id',
          name: ' ',
          text: 'text',
          alignment: StatusBarAlignment.left,
          priority: 0,
        ),
      ),
      throwsArgumentError,
    );
    service.dispose();
  });

  test('restores visibility preferences across service instances', () async {
    final store = InMemoryStatusBarPreferencesStore(hiddenEntryIds: {'hidden'});
    final firstService = StatusBarService(preferencesStore: store);
    await firstService.initialize();
    firstService.addEntry(entry('hidden'));
    firstService.addEntry(entry('visible'));
    expect(firstService.visibleEntries.map((entry) => entry.id), ['visible']);

    await firstService.setEntryVisible('hidden', true);
    expect(firstService.visibleEntries.map((entry) => entry.id), [
      'hidden',
      'visible',
    ]);
    firstService.dispose();

    final nextService = StatusBarService(preferencesStore: store);
    await nextService.initialize();
    nextService.addEntry(entry('hidden'));
    expect(nextService.isEntryVisible('hidden'), isTrue);
    nextService.dispose();
  });

  test(
    'serializes visibility changes and notifies only on transitions',
    () async {
      final service = StatusBarService(
        preferencesStore: InMemoryStatusBarPreferencesStore(),
      );
      await service.initialize();
      service.addEntry(entry('toggle'));
      var notifications = 0;
      service.addListener(() => notifications++);

      await Future.wait([
        service.setEntryVisible('toggle', false),
        service.setEntryVisible('toggle', true),
      ]);

      expect(service.isEntryVisible('toggle'), isTrue);
      expect(notifications, 2);
      service.dispose();
    },
  );

  test(
    'reports failed persistence while retaining the session visibility change',
    () async {
      final service = StatusBarService(preferencesStore: _FailingStore());
      await service.initialize();
      service.addEntry(entry('entry'));

      await expectLater(
        service.setEntryVisible('entry', false),
        throwsStateError,
      );
      expect(service.isEntryVisible('entry'), isFalse);
      service.dispose();
    },
  );
}

class _FailingStore implements StatusBarPreferencesStore {
  @override
  Future<Set<String>> readHiddenEntryIds() async => {};

  @override
  Future<void> writeHiddenEntryIds(Set<String> ids) async {
    throw StateError('write failed');
  }
}
