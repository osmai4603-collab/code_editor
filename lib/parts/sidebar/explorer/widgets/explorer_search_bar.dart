import 'package:flutter/material.dart';

import '../../../../core/file_system/controllers/file_explorer_controller.dart';
import '../../../../core/theme/editor_theme.dart';

class ExplorerSearchBar extends StatefulWidget {
  final FileExplorerController controller;

  const ExplorerSearchBar({super.key, required this.controller});

  @override
  State<ExplorerSearchBar> createState() => _ExplorerSearchBarState();
}

class _ExplorerSearchBarState extends State<ExplorerSearchBar> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void didUpdateWidget(ExplorerSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.controller.searchQuery;
    if (_textController.text != value) {
      _textController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: TextField(
        controller: _textController,
        style: TextStyle(color: theme.sideBarForeground, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Filter files by name',
          prefixIcon: const Icon(Icons.search, size: 15),
          suffixIcon: widget.controller.searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () {
                    _textController.clear();
                    widget.controller.setSearchQuery('');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
          border: const OutlineInputBorder(),
        ),
        onChanged: widget.controller.setSearchQuery,
      ),
    );
  }
}
