import 'dart:typed_data';
import 'token_metadata.dart';

/// تمثيل رموز السطر الواحد عبر مصفوفة أعداد صحيحة `Int32List`
///
/// الهيكل الداخلي للمصفوفة:
/// `[endOffset0, metadata0, endOffset1, metadata1, ...]`
class LineTokens {
  final Int32List binaryTokens;
  final int lineLength;

  const LineTokens({
    required this.binaryTokens,
    required this.lineLength,
  });

  /// إنشاء رموز افتراضية لسطر فارغ أو غير منسق
  factory LineTokens.empty(int length, [int defaultMetadata = 0]) {
    if (length <= 0) {
      return LineTokens(binaryTokens: Int32List(0), lineLength: 0);
    }
    final list = Int32List(2);
    list[0] = length;
    list[1] = defaultMetadata;
    return LineTokens(binaryTokens: list, lineLength: length);
  }

  /// عدد الرموز في السطر
  int get count => binaryTokens.length ~/ 2;

  /// بداية موضع الرمز في السطر (0-indexed)
  int getStartOffset(int tokenIndex) {
    if (tokenIndex <= 0) return 0;
    return binaryTokens[(tokenIndex - 1) * 2];
  }

  /// نهاية موضع الرمز في السطر
  int getEndOffset(int tokenIndex) {
    return binaryTokens[tokenIndex * 2];
  }

  /// البيانات الوصفية المشفرة للرمز
  int getMetadata(int tokenIndex) {
    return binaryTokens[tokenIndex * 2 + 1];
  }

  /// معرف لون الرمز الأمامي
  int getForeground(int tokenIndex) {
    return TokenMetadata.getForeground(getMetadata(tokenIndex));
  }

  /// البحث عن فهرس الرمز عند موضع حرف معين (Binary Search)
  int findTokenIndexAtOffset(int charOffset) {
    if (count == 0) return 0;
    int low = 0;
    int high = count - 1;

    while (low < high) {
      final mid = low + ((high - low) >> 1);
      final endOffset = binaryTokens[mid * 2];

      if (endOffset <= charOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
