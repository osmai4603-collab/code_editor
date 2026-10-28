class FlowController {
  static const highWatermark = 100000;
  static const lowWatermark = 5000;

  int _unacknowledgedChars = 0;
  bool _isPaused = false;

  bool get isPaused => _isPaused;

  bool shouldPause(int incomingChars) {
    _unacknowledgedChars += incomingChars;
    if (_unacknowledgedChars >= highWatermark) _isPaused = true;
    return _isPaused;
  }

  void acknowledge(int processedChars) {
    _unacknowledgedChars = (_unacknowledgedChars - processedChars).clamp(
      0,
      highWatermark,
    );
    if (_isPaused && _unacknowledgedChars <= lowWatermark) _isPaused = false;
  }
}
