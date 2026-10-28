import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/status_bar_alignment.dart';
import 'models/status_bar_entry.dart';
import 'status_bar_preferences_store.dart';

class StatusBarService extends ChangeNotifier {
  final StatusBarPreferencesStore _preferencesStore;
  final Map<String, _RegisteredEntry> _entries = {};
  Set<String> _hiddenEntryIds = {};
  Future<void>? _initialization;
  Future<void> _writeQueue = Future<void>.value();
  int _nextInsertionOrder = 0;
  bool _isDisposed = false;

  StatusBarService({
    required StatusBarPreferencesStore preferencesStore,
  }) : _preferencesStore = preferencesStore;

  Future<void> initialize() => _initialization ??= _loadPreferences();

  Future<void> _loadPreferences() async {
    try {
      _hiddenEntryIds = await _preferencesStore.readHiddenEntryIds();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'status bar',
          context: ErrorDescription('while reading saved visibility settings'),
        ),
      );
      _hiddenEntryIds = {};
    }
  }

  List<StatusBarEntry> get entries => List.unmodifiable(_orderedEntries);

  List<StatusBarEntry> get visibleEntries => List.unmodifiable(
    _orderedEntries.where((entry) => isEntryVisible(entry.id)),
  );

  List<StatusBarEntry> get _orderedEntries {
    final registered = _entries.values.toList()
      ..sort((first, second) {
        final alignmentOrder = _alignmentOrder(
          first.entry.alignment,
        ).compareTo(_alignmentOrder(second.entry.alignment));
        if (alignmentOrder != 0) return alignmentOrder;
        final priorityOrder = second.entry.priority.compareTo(
          first.entry.priority,
        );
        if (priorityOrder != 0) return priorityOrder;
        return first.insertionOrder.compareTo(second.insertionOrder);
      });
    return registered.map((registeredEntry) => registeredEntry.entry).toList();
  }

  int _alignmentOrder(StatusBarAlignment alignment) =>
      alignment == StatusBarAlignment.left ? 0 : 1;

  StatusBarEntryHandle addEntry(StatusBarEntry entry) {
    _ensureNotDisposed();
    if (_entries.containsKey(entry.id)) {
      throw ArgumentError.value(entry.id, 'entry.id', 'must be unique');
    }
    _entries[entry.id] = _RegisteredEntry(
      entry,
      _nextInsertionOrder++,
    );
    notifyListeners();
    return StatusBarEntryHandle._(this, entry.id);
  }

  bool isEntryVisible(String id) => !_hiddenEntryIds.contains(id);

  Future<void> setEntryVisible(String id, bool visible) {
    _ensureNotDisposed();
    if (!_entries.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'no status bar entry exists');
    }
    if (isEntryVisible(id) == visible) return Future<void>.value();

    final completer = Completer<void>();
    _writeQueue = _writeQueue
        .then((_) async {
          _ensureNotDisposed();
          final nextHiddenIds = Set<String>.of(_hiddenEntryIds);
          if (visible) {
            nextHiddenIds.remove(id);
          } else {
            nextHiddenIds.add(id);
          }
          await _preferencesStore.writeHiddenEntryIds(nextHiddenIds);
          _hiddenEntryIds = nextHiddenIds;
          notifyListeners();
        })
        .then(
          (_) => completer.complete(),
          onError: (Object error, StackTrace stackTrace) {
            completer.completeError(error, stackTrace);
          },
        );
    return completer.future;
  }

  void _updateEntry(String id, StatusBarEntry entry) {
    _ensureNotDisposed();
    if (entry.id != id) {
      throw ArgumentError.value(entry.id, 'entry.id', 'cannot change identity');
    }
    final registered = _entries[id];
    if (registered == null) return;
    registered.entry = entry;
    notifyListeners();
  }

  void _removeEntry(String id) {
    if (_isDisposed) return;
    if (_entries.remove(id) != null) notifyListeners();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('StatusBarService has been disposed');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _entries.clear();
    super.dispose();
  }
}

class StatusBarEntryHandle {
  final StatusBarService _service;
  final String id;
  bool _isDisposed = false;

  StatusBarEntryHandle._(this._service, this.id);

  void update(StatusBarEntry entry) {
    if (_isDisposed) return;
    _service._updateEntry(id, entry);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _service._removeEntry(id);
  }
}

class _RegisteredEntry {
  StatusBarEntry entry;
  final int insertionOrder;

  _RegisteredEntry(this.entry, this.insertionOrder);
}
