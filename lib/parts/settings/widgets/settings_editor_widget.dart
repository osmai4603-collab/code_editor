import 'package:code_editor/core/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/configuration/contracts/configuration_target.dart';
import '../../../core/configuration/services/configuration_service.dart';
import '../../../core/configuration/widgets/configuration_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../models/settings_editor_view_state.dart';
import '../models/settings_layout.dart';
import '../renderers/setting_control_renderer.dart';
import '../search/settings_search_engine.dart';

class SettingsEditorWidget extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const SettingsEditorWidget({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<SettingsEditorWidget> createState() => _SettingsEditorWidgetState();
}

class _SettingsEditorWidgetState extends State<SettingsEditorWidget> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late SettingsEditorViewState _viewState;
  late final ScrollController _scrollController;
  final SettingsSearchEngine _searchEngine = SettingsSearchEngine();
  double _tocWidth = 220;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController();
    _viewState = SettingsEditorViewState(
      query: widget.initialQuery ?? '',
      category: widget.initialCategory ?? 'Commonly Used',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _viewState = _viewState.copyWith(query: widget.initialQuery);
    }
    if (widget.initialCategory != oldWidget.initialCategory &&
        widget.initialCategory != null) {
      _viewState = _viewState.copyWith(category: widget.initialCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configuration = ConfigurationScope.of(context);
    final registry = configuration.registry;
    final allSettings = registry.definitions;
    final results = _searchEngine.search(
      _viewState.query.isEmpty
          ? SettingsLayout.settingsFor(registry, _viewState.category)
          : allSettings,
      _viewState.query,
      inspect: (key) =>
          configuration.inspect<Object?>(key, target: _viewState.target),
    );
    final theme = AppTheme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 700;
    return Material(
      color: theme.editorTheme.editorBackground,
      child: Column(
        children: [
          _buildHeader(configuration, theme),
          Expanded(
            child: Row(
              children: [
                if (!isNarrow) ...[
                  SizedBox(width: _tocWidth, child: _buildContents(theme)),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _tocWidth = (_tocWidth + details.delta.dx).clamp(
                            150.0,
                            360.0,
                          );
                        });
                      },
                      child: const SizedBox(
                        width: 5,
                        child: VerticalDivider(width: 1, thickness: 1),
                      ),
                    ),
                  ),
                ],
                Expanded(child: _buildResults(configuration, results, theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConfigurationService configuration, AppThemeData theme) {
    final foreground = theme.editorTheme.editorForeground;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.editorTheme.sideBarBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  style: TextStyle(color: foreground, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search settings',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: _viewState.query.isEmpty
                        ? const Icon(Icons.filter_list, size: 19)
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(
                                () =>
                                    _viewState = _viewState.copyWith(query: ''),
                              );
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xff3c3c3c),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) => setState(
                    () => _viewState = _viewState.copyWith(query: value),
                  ),
                  onSubmitted: (_) => _searchFocusNode.unfocus(),
                ),
              ),
              const SizedBox(width: 12),
              _targetTab(
                label: 'User',
                selected: _viewState.target == ConfigurationTarget.user,
                onTap: () => setState(
                  () => _viewState = _viewState.copyWith(
                    target: ConfigurationTarget.user,
                  ),
                ),
                foreground: foreground,
              ),
              _targetTab(
                label: 'Workspace',
                selected: _viewState.target == ConfigurationTarget.workspace,
                onTap: () => setState(
                  () => _viewState = _viewState.copyWith(
                    target: ConfigurationTarget.workspace,
                  ),
                ),
                foreground: foreground,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _targetTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color foreground,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? const Color(0xff0078d4) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground.withValues(alpha: selected ? 1 : 0.7),
          fontSize: 12,
        ),
      ),
    ),
  );

  Widget _buildContents(AppThemeData theme) {
    final foreground = theme.editorTheme.editorForeground;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final section in SettingsLayout.categories) ...[
          _categoryTile(section.name, foreground, isHeader: true),
          for (final child in section.children)
            _categoryTile(child.name, foreground, indent: 18),
        ],
      ],
    );
  }

  Widget _categoryTile(
    String category,
    Color foreground, {
    bool isHeader = false,
    double indent = 0,
  }) => InkWell(
    onTap: () => setState(
      () => _viewState = _viewState.copyWith(category: category, query: ''),
    ),
    child: Container(
      color: _viewState.category == category
          ? const Color(0xff37373d)
          : Colors.transparent,
      padding: EdgeInsets.fromLTRB(14 + indent, 7, 8, 7),
      child: Text(
        category,
        style: TextStyle(
          color: foreground.withValues(alpha: isHeader ? 1 : 0.82),
          fontSize: isHeader ? 12 : 12,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );

  Widget _buildResults(
    ConfigurationService configuration,
    List<SettingSearchResult> results,
    AppThemeData theme,
  ) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No settings found',
          style: TextStyle(
            color: theme.editorTheme.editorForeground.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final setting = results[index].setting;
        final inspected = configuration.inspect<Object?>(
          setting.key,
          target: _viewState.target,
        );
        return _settingCard(context, configuration, setting, inspected, theme);
      },
    );
  }

  Widget _settingCard(
    BuildContext context,
    ConfigurationService configuration,
    setting,
    inspected,
    AppThemeData theme,
  ) {
    final foreground = theme.editorTheme.editorForeground;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: inspected.isModified
                ? const Color(0xff0078d4)
                : Colors.transparent,
            width: 2,
          ),
          bottom: BorderSide(color: theme.editorTheme.sideBarBorder),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setting.title,
                      style: TextStyle(color: foreground, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      setting.key,
                      style: const TextStyle(
                        color: Color(0xff9da0a6),
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SettingControlRenderer.build(
                setting: setting,
                inspectResult: inspected,
                onChanged: (value) =>
                    _updateSetting(context, configuration, setting.key, value),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (action) => _runAction(
                  context,
                  configuration,
                  action,
                  setting.key,
                  inspected.effectiveValue,
                ),
                itemBuilder: (_) => [
                  if (inspected.isModified)
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Reset Setting'),
                    ),
                  const PopupMenuItem(
                    value: 'copy-id',
                    child: Text('Copy Setting ID'),
                  ),
                  const PopupMenuItem(
                    value: 'copy-json',
                    child: Text('Copy Setting as JSON'),
                  ),
                ],
                icon: const Icon(Icons.more_vert, size: 18),
              ),
            ],
          ),
          if (setting.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              setting.description,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
          ],
          if (inspected.isModified)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Modified in ${_viewState.target.name[0].toUpperCase()}${_viewState.target.name.substring(1)}',
                style: const TextStyle(color: Color(0xff3794ff), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(
    BuildContext context,
    configuration,
    String key,
    Object? value,
  ) async {
    try {
      await configuration.updateValue(key, value, target: _viewState.target);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update "$key": $error')),
        );
      }
    }
  }

  Future<void> _runAction(
    BuildContext context,
    configuration,
    String action,
    String key,
    Object? value,
  ) async {
    try {
      switch (action) {
        case 'reset':
          await configuration.resetValue(key, target: _viewState.target);
          return;
        case 'copy-id':
          await Clipboard.setData(ClipboardData(text: key));
          return;
        case 'copy-json':
          await Clipboard.setData(ClipboardData(text: '"$key": $value'));
          return;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to complete setting action: $error')),
        );
      }
    }
  }
}
