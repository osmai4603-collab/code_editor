import 'package:flutter/material.dart';

class DeleteConfirmDialog extends StatelessWidget {
  final List<String> names;

  const DeleteConfirmDialog({super.key, required this.names});

  static Future<bool> show(BuildContext context, List<String> names) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => DeleteConfirmDialog(names: names),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final prompt = names.length == 1
        ? 'Are you sure you want to delete "${names.single}"?'
        : 'Are you sure you want to delete ${names.length} items?';
    return AlertDialog(
      title: const Text('Delete'),
      content: Text('$prompt This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
