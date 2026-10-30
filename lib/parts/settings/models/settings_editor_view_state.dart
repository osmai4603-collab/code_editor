import '../../../core/configuration/contracts/configuration_target.dart';

class SettingsEditorViewState {
  final ConfigurationTarget target;
  final String category;
  final String query;
  final double scrollOffset;

  const SettingsEditorViewState({
    this.target = ConfigurationTarget.user,
    this.category = 'Commonly Used',
    this.query = '',
    this.scrollOffset = 0,
  });

  SettingsEditorViewState copyWith({
    ConfigurationTarget? target,
    String? category,
    String? query,
    double? scrollOffset,
  }) => SettingsEditorViewState(
    target: target ?? this.target,
    category: category ?? this.category,
    query: query ?? this.query,
    scrollOffset: scrollOffset ?? this.scrollOffset,
  );
}
