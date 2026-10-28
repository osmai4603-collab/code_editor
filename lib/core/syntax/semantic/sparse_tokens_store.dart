import '../../lsp/protocol/lsp_semantic_tokens_types.dart';

/// مخزن الرموز الدلالية المتفرقة (Sparse Tokens Store) للمستند
class SparseTokensStore {
  final Map<int, List<DecodedSemanticToken>> _lineTokens = {};
  String? _resultId;

  String? get resultId => _resultId;
  bool get isEmpty => _lineTokens.isEmpty;

  /// تعيين الرموز الدلالية الجديدة بعد استلامها وفك تشفيرها
  void setTokens(List<DecodedSemanticToken> tokens, [String? resultId]) {
    _lineTokens.clear();
    _resultId = resultId;

    for (final token in tokens) {
      final list = _lineTokens.putIfAbsent(token.line, () => []);
      list.add(token);
    }

    // فرز الرموز داخل كل سطر حسب موضع البداية تصاعدياً
    for (final list in _lineTokens.values) {
      list.sort((a, b) => a.startChar.compareTo(b.startChar));
    }
  }

  /// استرجاع الرموز الدلالية لسطر معين
  List<DecodedSemanticToken>? getTokensForLine(int line) {
    return _lineTokens[line];
  }

  /// مسح كافة الرموز المخزنة
  void clear() {
    _lineTokens.clear();
    _resultId = null;
  }
}
