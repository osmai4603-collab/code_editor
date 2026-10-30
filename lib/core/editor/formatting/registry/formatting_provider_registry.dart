import '../contracts/formatting_types.dart';
import 'package:code_editor/core/lsp/protocol/lsp_types.dart';
import 'language_feature_score.dart';

abstract interface class FormattingDisposable {
  void dispose();
}

class _ProviderRegistration<T extends Object> implements FormattingDisposable {
  final T provider;
  final String? uriPattern;
  final void Function(_ProviderRegistration<T>) remove;
  bool _disposed = false;

  _ProviderRegistration({
    required this.provider,
    required this.uriPattern,
    required this.remove,
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    remove(this);
  }
}

class FormattingProviderRegistry {
  final List<_ProviderRegistration<DocumentFormattingEditProvider>>
  _documentProviders = [];
  final List<_ProviderRegistration<DocumentRangeFormattingEditProvider>>
  _rangeProviders = [];
  final List<
    _ProviderRegistration<DocumentMultiRangeFormattingEditProvider>
  >
  _multiRangeProviders = [];
  final List<_ProviderRegistration<OnTypeFormattingEditProvider>>
  _onTypeProviders = [];

  FormattingDisposable registerDocumentProvider(
    DocumentFormattingEditProvider provider, {
    String? uriPattern,
  }) => _register(_documentProviders, provider, uriPattern);

  FormattingDisposable registerRangeProvider(
    DocumentRangeFormattingEditProvider provider, {
    String? uriPattern,
  }) => _register(_rangeProviders, provider, uriPattern);

  FormattingDisposable registerMultiRangeProvider(
    DocumentMultiRangeFormattingEditProvider provider, {
    String? uriPattern,
  }) => _register(_multiRangeProviders, provider, uriPattern);

  FormattingDisposable registerOnTypeProvider(
    OnTypeFormattingEditProvider provider, {
    String? uriPattern,
  }) => _register(_onTypeProviders, provider, uriPattern);

  List<DocumentFormattingEditProvider> documentProvidersFor(
    FormattingDocument document,
  ) {
    final candidates =
        <(DocumentFormattingEditProvider, int, int)>[];
    var order = 0;
    for (final registration in _documentProviders) {
      final score = _score(registration, document);
      if (score > 0) candidates.add((registration.provider, score, order++));
    }
    final registeredIds = candidates.map((candidate) => candidate.$1.id).toSet();
    for (final registration in _rangeProviders) {
      final score = _score(registration, document);
      if (score <= 0 || !registeredIds.add(registration.provider.id)) continue;
      candidates.add((
        SyntheticFormattingProvider(registration.provider),
        score,
        order++,
      ));
    }
    candidates.sort((a, b) {
      final score = b.$2.compareTo(a.$2);
      return score == 0 ? a.$3.compareTo(b.$3) : score;
    });
    return List.unmodifiable(candidates.map((candidate) => candidate.$1));
  }

  List<DocumentRangeFormattingEditProvider> rangeProvidersFor(
    FormattingDocument document,
  ) => _matching(_rangeProviders, document);

  List<DocumentMultiRangeFormattingEditProvider> multiRangeProvidersFor(
    FormattingDocument document,
  ) => _matching(_multiRangeProviders, document);

  List<OnTypeFormattingEditProvider> onTypeProvidersFor(
    FormattingDocument document,
  ) => _matching(_onTypeProviders, document);

  List<T> _matching<T extends Object>(
    List<_ProviderRegistration<T>> registrations,
    FormattingDocument document,
  ) {
    final matches = registrations
        .map((registration) => (registration, _score(registration, document)))
        .where((match) => match.$2 > 0)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return List.unmodifiable(matches.map((match) => match.$1.provider));
  }

  int _score<T extends Object>(
    _ProviderRegistration<T> registration,
    FormattingDocument document,
  ) {
    final provider = registration.provider;
    final languages = switch (provider) {
      DocumentFormattingEditProvider() => provider.languageIds,
      DocumentRangeFormattingEditProvider() => provider.languageIds,
      DocumentMultiRangeFormattingEditProvider() => provider.languageIds,
      OnTypeFormattingEditProvider() => provider.languageIds,
      _ => const <String>{},
    };
    return LanguageFeatureScore.forDocument(
      languageId: document.languageId,
      uri: document.uri,
      languageIds: languages,
      uriPattern: registration.uriPattern,
    );
  }

  FormattingDisposable _register<T extends Object>(
    List<_ProviderRegistration<T>> registrations,
    T provider,
    String? uriPattern,
  ) {
    final registration = _ProviderRegistration<T>(
      provider: provider,
      uriPattern: uriPattern,
      remove: registrations.remove,
    );
    registrations.add(registration);
    return registration;
  }
}

class SyntheticFormattingProvider implements DocumentFormattingEditProvider {
  final DocumentRangeFormattingEditProvider rangeProvider;

  const SyntheticFormattingProvider(this.rangeProvider);

  @override
  String get id => rangeProvider.id;

  @override
  Set<String> get languageIds => rangeProvider.languageIds;

  @override
  Future<List<TextEdit>> provideDocumentFormattingEdits(
    FormattingDocument document,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) async {
    final lines = document.text.split('\n');
    final lastLine = lines.last;
    final lastLineLength = lastLine.endsWith('\r')
        ? lastLine.length - 1
        : lastLine.length;
    return rangeProvider.provideDocumentRangeFormattingEdits(
      document,
      LspRange(
        start: const LspPosition(line: 0, character: 0),
        end: LspPosition(line: lines.length - 1, character: lastLineLength),
      ),
      options,
      cancellationToken: cancellationToken,
    );
  }
}
