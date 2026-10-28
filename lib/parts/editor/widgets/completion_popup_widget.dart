import 'package:flutter/material.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';

/// قائمة الإكمال التلقائي العائمة (Completion Popup Widget)
class CompletionPopupWidget extends StatefulWidget {
  final List<CompletionItem> items;
  final ValueChanged<CompletionItem> onSelected;
  final VoidCallback onDismiss;
  final Offset position;

  const CompletionPopupWidget({
    super.key,
    required this.items,
    required this.onSelected,
    required this.onDismiss,
    required this.position,
  });

  @override
  State<CompletionPopupWidget> createState() => _CompletionPopupWidgetState();
}

class _CompletionPopupWidgetState extends State<CompletionPopupWidget> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = EditorTheme.of(context);
    final selectedItem = widget.items[_selectedIndex.clamp(0, widget.items.length - 1)];

    return Positioned(
      left: widget.position.dx.clamp(40.0, 600.0),
      top: widget.position.dy.clamp(30.0, 500.0),
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: theme.editorBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.tabBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // قائمة المقترحات
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = index == _selectedIndex;

                    return InkWell(
                      onHover: (hovering) {
                        if (hovering && _selectedIndex != index) {
                          setState(() => _selectedIndex = index);
                        }
                      },
                      onTap: () => widget.onSelected(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        color: isSelected ? theme.accentColor.withValues(alpha: 0.25) : Colors.transparent,
                        child: Row(
                          children: [
                            _buildKindIcon(item.kind),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: theme.editorForeground,
                                  fontSize: 12.5,
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (item.detail != null)
                              Text(
                                item.detail!,
                                style: TextStyle(
                                  color: theme.editorForeground.withValues(alpha: 0.45),
                                  fontSize: 11,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // معاينة توثيق العنصر المختار
              if (selectedItem.documentation != null && selectedItem.documentation!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    border: Border(
                      top: BorderSide(color: theme.tabBorder.withValues(alpha: 0.4), width: 1.0),
                    ),
                  ),
                  child: Text(
                    selectedItem.documentation!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.editorForeground.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKindIcon(CompletionItemKind kind) {
    IconData icon;
    Color color;

    switch (kind) {
      case CompletionItemKind.method:
      case CompletionItemKind.function:
        icon = Icons.functions_rounded;
        color = const Color(0xFFC586C0); // بنفسجي توابع VS Code
        break;
      case CompletionItemKind.classKind:
      case CompletionItemKind.interfaceKind:
      case CompletionItemKind.struct:
        icon = Icons.category_rounded;
        color = const Color(0xFF4EC9B0); // تركواز أصناف VS Code
        break;
      case CompletionItemKind.variable:
      case CompletionItemKind.field:
      case CompletionItemKind.property:
        icon = Icons.data_object_rounded;
        color = const Color(0xFF9CDCFE); // أزرق متغيرات
        break;
      case CompletionItemKind.keyword:
        icon = Icons.vpn_key_rounded;
        color = const Color(0xFF569CD6); // أزرق كلمات محجوزة
        break;
      case CompletionItemKind.snippet:
        icon = Icons.code_rounded;
        color = const Color(0xFFDCDCAA);
        break;
      default:
        icon = Icons.text_fields_rounded;
        color = Colors.grey;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }
}
