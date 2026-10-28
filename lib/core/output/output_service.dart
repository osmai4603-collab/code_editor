import 'package:flutter/foundation.dart';

import '../execution/execution_controller.dart';
import '../execution/execution_session.dart';

class OutputChannel {
  final String id;
  final String title;
  final String source;
  final ExecutionSession session;

  const OutputChannel({
    required this.id,
    required this.title,
    required this.source,
    required this.session,
  });

  List<ExecutionOutputLine> get lines => session.lines;
}

class OutputService extends ChangeNotifier {
  final ExecutionController executionController;
  String? _selectedChannelId;
  String? _lastActiveSessionId;
  bool _disposed = false;

  OutputService(this.executionController)
    : _lastActiveSessionId = executionController.activeSession?.id {
    executionController.addListener(_handleExecutionChanged);
  }

  List<OutputChannel> get channels => List.unmodifiable([
    for (final session in executionController.history)
      OutputChannel(
        id: session.id,
        title: _channelTitle(session),
        source: 'Execution',
        session: session,
      ),
  ]);

  OutputChannel? get selectedChannel {
    final selectedId = _selectedChannelId;
    if (selectedId != null) {
      for (final channel in channels) {
        if (channel.id == selectedId) return channel;
      }
    }
    final activeId = executionController.activeSession?.id;
    if (activeId == null) return null;
    for (final channel in channels) {
      if (channel.id == activeId) return channel;
    }
    return null;
  }

  void selectChannel(String channelId) {
    if (!channels.any((channel) => channel.id == channelId)) {
      throw ArgumentError.value(
        channelId,
        'channelId',
        'Unknown output channel',
      );
    }
    if (_selectedChannelId == channelId) return;
    _selectedChannelId = channelId;
    notifyListeners();
  }

  void clearChannel(String channelId) {
    OutputChannel? target;
    for (final channel in channels) {
      if (channel.id == channelId) {
        target = channel;
        break;
      }
    }
    if (target == null) {
      throw ArgumentError.value(
        channelId,
        'channelId',
        'Unknown output channel',
      );
    }
    executionController.clearOutput(session: target.session);
  }

  void _handleExecutionChanged() {
    final activeId = executionController.activeSession?.id;
    if (activeId != _lastActiveSessionId) {
      _lastActiveSessionId = activeId;
      _selectedChannelId = activeId;
    }
    if (!_disposed) notifyListeners();
  }

  static String _channelTitle(ExecutionSession session) {
    final path = session.args.isEmpty ? session.command : session.args.last;
    final pathParts = path
        .split(RegExp(r'[/\\]'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final basename = pathParts.isEmpty ? session.command : pathParts.last;
    final started = session.startTime;
    final time =
        '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}:${started.second.toString().padLeft(2, '0')}';
    return '$basename · $time';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    executionController.removeListener(_handleExecutionChanged);
    super.dispose();
  }
}
