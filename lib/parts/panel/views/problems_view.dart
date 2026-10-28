import 'package:flutter/material.dart';
import '../../../core/lsp/diagnostics/diagnostics_service.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../layout/controllers/editor_controller.dart';

/// شاشة عرض المشاكل والأخطاء والتحذيرات في اللوحة السفلية (Problems View)
class ProblemsView extends StatelessWidget {
  final DiagnosticsService diagnosticsService;

  const ProblemsView({
    super.key,
    required this.diagnosticsService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EditorTheme.of(context);
    final documentsController = EditorDocumentsScope.of(context);

    return ListenableBuilder(
      listenable: diagnosticsService,
      builder: (context, _) {
        final grouped = diagnosticsService.diagnosticsByUri;

        if (grouped.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: Colors.greenAccent.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No problems have been detected in the workspace.',
                  style: TextStyle(
                    color: theme.panelForeground.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (final entry in grouped.entries)
              _buildFileProblemsGroup(
                entry.key,
                entry.value,
                theme,
                documentsController,
              ),
          ],
        );
      },
    );
  }

  Widget _buildFileProblemsGroup(
    String uri,
    List<DiagnosticItem> items,
    EditorThemeData theme,
    EditorDocumentsController documentsController,
  ) {
    final fileName = uri.split('/').last;

    return Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(
          Icons.description_outlined,
          size: 16,
          color: theme.editorForeground.withValues(alpha: 0.7),
        ),
        title: Row(
          children: [
            Text(
              fileName,
              style: TextStyle(
                color: theme.panelForeground,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              uri,
              style: TextStyle(
                color: theme.panelForeground.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(color: theme.accentColor, fontSize: 10.5),
              ),
            ),
          ],
        ),
        children: items.map((item) => _buildProblemItem(item, theme, documentsController)).toList(),
      ),
    );
  }

  Widget _buildProblemItem(
    DiagnosticItem item,
    EditorThemeData theme,
    EditorDocumentsController documentsController,
  ) {
    IconData icon;
    Color iconColor;

    switch (item.severity) {
      case DiagnosticSeverity.error:
        icon = Icons.error_outline_rounded;
        iconColor = Colors.redAccent;
        break;
      case DiagnosticSeverity.warning:
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.amberAccent;
        break;
      case DiagnosticSeverity.information:
        icon = Icons.info_outline_rounded;
        iconColor = Colors.blueAccent;
        break;
      case DiagnosticSeverity.hint:
        icon = Icons.lightbulb_outline_rounded;
        iconColor = Colors.grey;
        break;
    }

    final line = item.range.start.line + 1;
    final char = item.range.start.character + 1;

    return InkWell(
      onTap: () {
        // فتح الملف أو التركيز عليه في المحرر
        final cleanPath = item.uri.startsWith('file://')
            ? item.uri.substring(7)
            : item.uri;
        final fileName = cleanPath.split('/').last;

        documentsController.openFile(
          title: fileName,
          path: cleanPath,
          content: '', // إذا كان مفتوحاً سيعتمد التبويب الحالي
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.message,
                style: TextStyle(color: theme.panelForeground, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '[$line, $char]',
              style: TextStyle(
                color: theme.panelForeground.withValues(alpha: 0.45),
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            if (item.source != null) ...[
              const SizedBox(width: 8),
              Text(
                item.source!,
                style: TextStyle(
                  color: theme.panelForeground.withValues(alpha: 0.35),
                  fontSize: 10.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
