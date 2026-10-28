import 'dart:async';
import 'dart:io';

enum FileChangeType { created, modified, deleted }

class FileChangeEvent {
  final String path;
  final FileChangeType type;
  final DateTime timestamp;

  const FileChangeEvent({
    required this.path,
    required this.type,
    required this.timestamp,
  });
}

class FileWatcherService {
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  final Map<String, FileChangeEvent> _pendingEvents = {};
  final StreamController<List<FileChangeEvent>> _controller =
      StreamController<List<FileChangeEvent>>.broadcast();

  Stream<List<FileChangeEvent>> get changes => _controller.stream;

  Future<void> watch(String directoryPath) async {
    await stop();
    _subscription = Directory(
      directoryPath,
    ).watch(recursive: true).listen(_onRawEvent, onError: _controller.addError);
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingEvents.clear();
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onRawEvent(FileSystemEvent event) {
    if (_isIgnored(event.path)) return;
    final type = switch (event.type) {
      FileSystemEvent.create => FileChangeType.created,
      FileSystemEvent.delete => FileChangeType.deleted,
      FileSystemEvent.modify || FileSystemEvent.move => FileChangeType.modified,
      _ => FileChangeType.modified,
    };
    final previous = _pendingEvents[event.path];
    if (previous?.type == FileChangeType.created &&
        type == FileChangeType.deleted) {
      _pendingEvents.remove(event.path);
    } else {
      _pendingEvents[event.path] = FileChangeEvent(
        path: event.path,
        type:
            previous?.type == FileChangeType.deleted &&
                type == FileChangeType.created
            ? FileChangeType.modified
            : type,
        timestamp: DateTime.now(),
      );
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    if (_pendingEvents.isEmpty || _controller.isClosed) return;
    _controller.add(List.unmodifiable(_pendingEvents.values));
    _pendingEvents.clear();
  }

  bool _isIgnored(String path) {
    const ignoredSegments = {'.git', 'build', '.dart_tool', 'node_modules'};
    return path.split(Platform.pathSeparator).any(ignoredSegments.contains);
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
