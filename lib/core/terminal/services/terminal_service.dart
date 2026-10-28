import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/terminal_profile.dart';
import '../models/terminal_state.dart';
import '../pty/pty_options.dart';
import 'terminal_process_manager.dart';

class TerminalService extends ChangeNotifier {
  final List<TerminalInstance> _instances = [];
  int _activeIndex = -1;
  int _nextId = 0;
  bool _disposed = false;

  List<TerminalInstance> get instances => List.unmodifiable(_instances);
  TerminalInstance? get activeInstance =>
      _activeIndex >= 0 && _activeIndex < _instances.length
      ? _instances[_activeIndex]
      : null;
  int get activeIndex => _activeIndex;

  Future<TerminalInstance> createTerminal({
    PtyOptions? options,
    String? title,
    TerminalProfile? profile,
  }) async {
    if (_disposed) throw StateError('The terminal service has been disposed.');
    final selectedOptions =
        options ??
        PtyOptions(
          executable: profile?.executablePath ?? PtyOptions.defaultShell,
          args: profile?.args ?? PtyOptions.defaultShellArgs,
          workingDirectory: Directory.current.path,
          environment: profile?.environment ?? const {},
        );
    final state = TerminalState(
      id: 'terminal_${_nextId++}',
      cols: selectedOptions.cols,
      rows: selectedOptions.rows,
      title: title ?? profile?.name ?? 'Terminal ${_instances.length + 1}',
    );
    final manager = TerminalProcessManager(state: state);
    final instance = TerminalInstance(state: state, processManager: manager);
    _instances.add(instance);
    _activeIndex = _instances.length - 1;
    notifyListeners();
    try {
      await manager.start(selectedOptions);
    } catch (_) {
      closeTerminal(_instances.indexOf(instance));
      rethrow;
    }
    return instance;
  }

  void setActiveTerminal(int index) {
    if (index < 0 || index >= _instances.length || index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  void closeTerminal(int index) {
    if (index < 0 || index >= _instances.length) return;
    _instances.removeAt(index).dispose();
    if (_instances.isEmpty) {
      _activeIndex = -1;
    } else if (index < _activeIndex) {
      _activeIndex--;
    } else if (_activeIndex >= _instances.length) {
      _activeIndex = _instances.length - 1;
    }
    notifyListeners();
  }

  void disposeAll() {
    for (final instance in _instances) {
      instance.dispose();
    }
    _instances.clear();
    _activeIndex = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final instance in _instances) {
      instance.dispose();
    }
    _instances.clear();
    super.dispose();
  }
}

class TerminalInstance {
  final TerminalState state;
  final TerminalProcessManager processManager;

  TerminalInstance({required this.state, required this.processManager});

  void dispose() {
    processManager.dispose();
    state.dispose();
  }
}
