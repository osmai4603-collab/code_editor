import '../contracts/formatting_types.dart';
import '../editor_formatting_preferences.dart';

enum FormatterResolutionStatus {
  selected,
  noProvider,
  defaultFormatterUnavailable,
  selectionRequiresRangeProvider,
  formatterDoesNotSupportKind,
  formatterChoiceRequired,
}

class FormatterResolution {
  final FormatterResolutionStatus status;
  final Object? provider;

  const FormatterResolution(this.status, {this.provider});
}

class DefaultFormatterService {
  const DefaultFormatterService();

  FormatterResolution resolve({
    required List<Object> providers,
    required EditorFormattingPreferences preferences,
    required String languageId,
    required FormattingKind kind,
    required FormattingMode mode,
  }) {
    final effective = preferences.forLanguage(languageId);
    if (providers.isEmpty) {
      return const FormatterResolution(FormatterResolutionStatus.noProvider);
    }

    final configuredId = effective.defaultFormatter;
    if (configuredId != null) {
      for (final provider in providers) {
        if (_idOf(provider) != configuredId) continue;
        if (!_supports(provider, kind)) {
          return const FormatterResolution(
            FormatterResolutionStatus.formatterDoesNotSupportKind,
          );
        }
        return FormatterResolution(
          FormatterResolutionStatus.selected,
          provider: provider,
        );
      }
      return const FormatterResolution(
        FormatterResolutionStatus.defaultFormatterUnavailable,
      );
    }

    if (providers.length == 1) {
      final provider = providers.single;
      if (!_supports(provider, kind)) {
        return const FormatterResolution(
          FormatterResolutionStatus.formatterDoesNotSupportKind,
        );
      }
      return FormatterResolution(
        FormatterResolutionStatus.selected,
        provider: provider,
      );
    }

    if (mode == FormattingMode.silent) {
      return const FormatterResolution(
        FormatterResolutionStatus.defaultFormatterUnavailable,
      );
    }
    return const FormatterResolution(
      FormatterResolutionStatus.formatterChoiceRequired,
    );
  }

  bool _supports(Object provider, FormattingKind kind) => switch (kind) {
    FormattingKind.file => provider is DocumentFormattingEditProvider,
    FormattingKind.selection =>
      provider is DocumentRangeFormattingEditProvider,
  };

  String? _idOf(Object provider) => switch (provider) {
    DocumentFormattingEditProvider() => provider.id,
    DocumentRangeFormattingEditProvider() => provider.id,
    _ => null,
  };
}
