import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InlineRenameField extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  const InlineRenameField({
    super.key,
    required this.initialName,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<InlineRenameField> createState() => _InlineRenameFieldState();
}

class _InlineRenameFieldState extends State<InlineRenameField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dot = widget.initialName.lastIndexOf('.');
      final end = dot > 0 ? dot : widget.initialName.length;
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: end);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      widget.onCancel();
      return;
    }
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onCancel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      style: const TextStyle(fontSize: 12.5, height: 1.2),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
      onTapOutside: (_) => _submit(),
      onEditingComplete: _submit,
    ),
  );
}
