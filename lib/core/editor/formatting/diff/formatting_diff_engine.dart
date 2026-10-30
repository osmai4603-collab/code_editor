import '../editor_text_change.dart';
import 'isolate_diff_worker.dart';

class FormattingDiffEngine {
  final IsolateDiffWorker _worker;

  const FormattingDiffEngine({this._worker = const IsolateDiffWorker()});

  Future<List<EditorTextChange>> compute(
    String originalText,
    String formattedText, {
    int diffLimit = 100000,
  }) => _worker.between(
    originalText,
    formattedText,
    diffLimit: diffLimit,
  );
}
