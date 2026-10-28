import 'package:flutter/material.dart';

enum MoveConflictChoice { replace, skip, cancel }

class MoveConflictDialog extends StatelessWidget {
  final String sourceName;
  final String targetDirectory;

  const MoveConflictDialog({
    super.key,
    required this.sourceName,
    required this.targetDirectory,
  });

  static Future<MoveConflictChoice> show(
    BuildContext context, {
    required String sourceName,
    required String targetDirectory,
  }) async =>
      await showDialog<MoveConflictChoice>(
        context: context,
        builder: (context) => MoveConflictDialog(
          sourceName: sourceName,
          targetDirectory: targetDirectory,
        ),
      ) ??
      MoveConflictChoice.cancel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('File already exists'),
    content: Text(
      'A file or folder named "$sourceName" already exists in "$targetDirectory".',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, MoveConflictChoice.cancel),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, MoveConflictChoice.skip),
        child: const Text('Skip'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, MoveConflictChoice.replace),
        child: const Text('Replace'),
      ),
    ],
  );
}
