import '../core/editor/indentation/editor_indentation_options.dart';

/// نموذج يمثل ملفاً أو تبويباً مفتوحاً في المحرر
class EditorTabItem {
  final String id;
  final String title;
  final String path;
  final String content;
  final bool isDirty;
  final bool isPreview;
  final String languageId;
  final EditorIndentationOptions? indentationOptions;

  const EditorTabItem({
    required this.id,
    required this.title,
    required this.path,
    required this.content,
    this.isDirty = false,
    this.isPreview = false,
    this.languageId = 'plaintext',
    this.indentationOptions,
  });

  EditorTabItem copyWith({
    String? id,
    String? title,
    String? path,
    String? content,
    bool? isDirty,
    bool? isPreview,
    String? languageId,
    EditorIndentationOptions? indentationOptions,
  }) {
    return EditorTabItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      content: content ?? this.content,
      isDirty: isDirty ?? this.isDirty,
      isPreview: isPreview ?? this.isPreview,
      languageId: languageId ?? this.languageId,
      indentationOptions: indentationOptions ?? this.indentationOptions,
    );
  }
}
