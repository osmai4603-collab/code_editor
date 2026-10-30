import '../contracts/formatting_types.dart';

class FormattingCancellationSource implements FormattingCancellationToken {
  bool _isCancellationRequested = false;

  @override
  bool get isCancellationRequested => _isCancellationRequested;

  void cancel() {
    _isCancellationRequested = true;
  }
}
