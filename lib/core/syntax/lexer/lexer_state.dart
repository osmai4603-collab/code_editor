/// تمثيل حالة المحلل النحوي عند نهاية السطر الواحد لدعم البنى متعددة الأسطر
class LexerState {
  /// الحالة الافتراضية العادية
  static const LexerState initial = LexerState();

  /// هل السطر ينتهي ونحن داخل تعليق كتلي غير منتهٍ `/* ... */`
  final bool inBlockComment;

  /// نوع علامة التنصيص متعددة الأسطر إن وجد (مثل `"""` أو `'''`)
  final String? inMultilineStringDelimiter;

  const LexerState({
    this.inBlockComment = false,
    this.inMultilineStringDelimiter,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LexerState &&
          runtimeType == other.runtimeType &&
          inBlockComment == other.inBlockComment &&
          inMultilineStringDelimiter == other.inMultilineStringDelimiter;

  @override
  int get hashCode => Object.hash(inBlockComment, inMultilineStringDelimiter);
}
