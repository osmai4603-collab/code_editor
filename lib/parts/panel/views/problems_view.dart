import 'package:flutter/material.dart';

import '../../../core/file_system/services/editor_file_opener.dart';
import '../../../core/file_system/services/file_system_service.dart';
import '../../../core/lsp/diagnostics/diagnostics_service.dart';
import '../../../core/lsp/diagnostics/problems_view_model.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../layout/controllers/editor_controller.dart';
import '../../../models/editor_tab_item.dart';

class ProblemsView extends StatefulWidget {
  final DiagnosticsService diagnosticsService;

  const ProblemsView({super.key, required this.diagnosticsService});

  @override
  State<ProblemsView> createState() => _ProblemsViewState();
}

class _ProblemsViewState extends State<ProblemsView> {
  final TextEditingController _searchController = TextEditingController();
  ProblemsViewFilter _filter = const ProblemsViewFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final documentsController = EditorDocumentsScope.of(context);
    final activeTab = documentsController.activeTab;

    return Column(
      children: [
        _buildToolbar(theme, activeTab?.path),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.diagnosticsService,
            builder: (context, _) {
              final allDiagnostics = widget.diagnosticsService.diagnosticsByUri;
              final filtered = ProblemsViewModel.filterAndSort(
                allDiagnostics,
                _filter.copyWith(activeFilePath: activeTab?.path),
              );
              final resultCount = filtered.values.fold<int>(
                0,
                (count, items) => count + items.length,
              );

              if (allDiagnostics.isEmpty) {
                return _emptyState(
                  theme,
                  icon: Icons.check_circle_outline_rounded,
                  message: 'No problems have been detected in the workspace.',
                );
              }
              if (filtered.isEmpty) {
                return _emptyState(
                  theme,
                  icon: Icons.filter_list_off_rounded,
                  message: 'No problems match the current filters.',
                  onClear: _clearFilters,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 2),
                    child: Text(
                      '$resultCount result${resultCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: theme.panelForeground.withValues(alpha: 0.55),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 6),
                      children: [
                        for (final entry in filtered.entries)
                          _buildFileProblemsGroup(
                            entry.key,
                            entry.value,
                            theme,
                            documentsController,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(EditorThemeData theme, String? activeFilePath) {
    final hasFilters = _filter.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.panelBorder.withValues(alpha: 0.45)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 220,
              height: 30,
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _filter = _filter.copyWith(query: value)),
                style: TextStyle(color: theme.panelForeground, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Filter problems',
                  hintStyle: TextStyle(
                    color: theme.panelForeground.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: theme.panelForeground.withValues(alpha: 0.55),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 30,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(
                              () => _filter = _filter.copyWith(query: ''),
                            );
                          },
                          icon: const Icon(Icons.close, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: theme.editorBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.panelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.panelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: theme.accentColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _severityFilter(
              'Errors',
              DiagnosticSeverity.error,
              _filter.showErrors,
              theme,
            ),
            _severityFilter(
              'Warnings',
              DiagnosticSeverity.warning,
              _filter.showWarnings,
              theme,
            ),
            _severityFilter(
              'Info',
              DiagnosticSeverity.information,
              _filter.showInformation,
              theme,
            ),
            _severityFilter(
              'Hints',
              DiagnosticSeverity.hint,
              _filter.showHints,
              theme,
            ),
            FilterChip(
              label: const Text('Active file'),
              tooltip: activeFilePath == null
                  ? 'Open a file to filter by the active file'
                  : 'Show problems in the active file only',
              selected: _filter.onlyActiveFile,
              onSelected: activeFilePath == null
                  ? null
                  : (selected) => setState(
                      () =>
                          _filter = _filter.copyWith(onlyActiveFile: selected),
                    ),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(color: theme.panelForeground, fontSize: 11),
              side: BorderSide(color: theme.panelBorder),
              backgroundColor: theme.panelBackground,
              selectedColor: theme.accentColor.withValues(alpha: 0.2),
            ),
            if (hasFilters)
              IconButton(
                tooltip: 'Clear all filters',
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_list_off, size: 16),
                visualDensity: VisualDensity.compact,
                color: theme.panelForeground.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }

  Widget _severityFilter(
    String label,
    DiagnosticSeverity severity,
    bool selected,
    EditorThemeData theme,
  ) {
    final color = theme.diagnosticColor(severity);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(label),
        tooltip: 'Toggle $label',
        selected: selected,
        onSelected: (value) => setState(() {
          _filter = switch (severity) {
            DiagnosticSeverity.error => _filter.copyWith(showErrors: value),
            DiagnosticSeverity.warning => _filter.copyWith(showWarnings: value),
            DiagnosticSeverity.information => _filter.copyWith(
              showInformation: value,
            ),
            DiagnosticSeverity.hint => _filter.copyWith(showHints: value),
          };
        }),
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(color: theme.panelForeground, fontSize: 11),
        side: BorderSide(color: selected ? color : theme.panelBorder),
        backgroundColor: theme.panelBackground,
        selectedColor: color.withValues(alpha: 0.18),
        checkmarkColor: color,
      ),
    );
  }

  Widget _emptyState(
    EditorThemeData theme, {
    required IconData icon,
    required String message,
    VoidCallback? onClear,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 34,
            color: theme.panelForeground.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.panelForeground.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (onClear != null)
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }

  Widget _buildFileProblemsGroup(
    String uri,
    List<DiagnosticItem> items,
    EditorThemeData theme,
    EditorDocumentsController documentsController,
  ) {
    final filePath = DiagnosticsService.pathForUri(uri);
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final errors = items
        .where((item) => item.severity == DiagnosticSeverity.error)
        .length;
    final warnings = items
        .where((item) => item.severity == DiagnosticSeverity.warning)
        .length;

    return ExpansionTile(
      key: PageStorageKey<String>('problems:$uri'),
      initiallyExpanded: true,
      dense: true,
      visualDensity: VisualDensity.compact,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.description_outlined,
        size: 16,
        color: theme.editorForeground.withValues(alpha: 0.7),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.panelForeground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filePath,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.panelForeground.withValues(alpha: 0.45),
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (errors > 0) _severityCount(errors, theme.diagnosticError),
          if (warnings > 0) ...[
            if (errors > 0) const SizedBox(width: 4),
            _severityCount(warnings, theme.diagnosticWarning),
          ],
          if (errors + warnings == 0)
            _severityCount(items.length, theme.accentColor),
        ],
      ),
      children: [
        for (final item in items)
          _buildProblemItem(item, theme, documentsController),
      ],
    );
  }

  Widget _severityCount(int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$count',
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildProblemItem(
    DiagnosticItem item,
    EditorThemeData theme,
    EditorDocumentsController documentsController,
  ) {
    final line = item.range.start.line + 1;
    final character = item.range.start.character + 1;
    final location = '[$line, $character]';
    final details = [
      if (item.source != null && item.source!.isNotEmpty) item.source!,
      if (item.code != null) item.code.toString(),
    ].join(' • ');

    return Semantics(
      button: true,
      label:
          '${item.severity.name}: ${item.message}, line $line, column $character',
      child: InkWell(
        onTap: () => _openDiagnostic(item, documentsController),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(36, 4, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  _severityIcon(item.severity),
                  size: 14,
                  color: theme.diagnosticColor(item.severity),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.message,
                      softWrap: true,
                      style: TextStyle(
                        color: theme.panelForeground,
                        fontSize: 12,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        style: TextStyle(
                          color: theme.panelForeground.withValues(alpha: 0.45),
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                location,
                style: TextStyle(
                  color: theme.panelForeground.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _severityIcon(DiagnosticSeverity severity) => switch (severity) {
    DiagnosticSeverity.error => Icons.error_outline_rounded,
    DiagnosticSeverity.warning => Icons.warning_amber_rounded,
    DiagnosticSeverity.information => Icons.info_outline_rounded,
    DiagnosticSeverity.hint => Icons.lightbulb_outline_rounded,
  };

  Future<void> _openDiagnostic(
    DiagnosticItem item,
    EditorDocumentsController documentsController,
  ) async {
    final path = DiagnosticsService.pathForUri(item.uri);
    try {
      EditorTabItem? existingTab;
      for (final tab in documentsController.tabs) {
        if (DiagnosticsService.normalizeUri(tab.path) ==
            DiagnosticsService.normalizeUri(path)) {
          existingTab = tab;
          break;
        }
      }
      final targetPath = existingTab?.path ?? path;

      if (existingTab != null) {
        documentsController.selectTab(existingTab.id);
      } else {
        await EditorFileOpener(
          FileSystemService(),
        ).open(editor: documentsController, path: path);
      }

      if (!mounted) return;
      documentsController.requestNavigation(
        path: targetPath,
        line: item.range.start.line,
        character: item.range.start.character,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Could not open problem: $error')),
          );
      }
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _filter = const ProblemsViewFilter());
  }
}
