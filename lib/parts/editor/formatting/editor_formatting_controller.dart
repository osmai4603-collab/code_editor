import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/editor/formatting/contracts/editor_formatting_service.dart';
import '../../../core/editor/formatting/contracts/formatting_types.dart';
import '../../../core/editor/formatting/conflicts/default_formatter_service.dart';
import '../../../core/editor/formatting/models/stable_editor_scroll_state.dart';
import '../../../core/editor/formatting/execution/formatting_execution_pipeline.dart';
import '../../../core/editor/formatting/execution/range_overlap_merger.dart';
import '../../../core/editor/formatting/editor_formatting_preferences.dart';
import '../../../core/editor/formatting/execution/scm_quick_diff_adapter.dart';
import '../../../core/editor/formatting/models/formatting_cancellation_token.dart';
import '../../../core/editor/formatting/registry/formatting_provider_registry.dart';
import '../../../core/editor/indentation/editor_indentation_options.dart';
import '../../../core/lsp/protocol/lsp_types.dart';
import '../controllers/code_editor_controller.dart';
import '../controllers/editor_lsp_extension.dart';

class EditorFormattingController {
  final CodeEditorController editorController;
  final EditorFormattingService service;
  final EditorFormattingPreferences Function() preferences;
  final String Function() languageId;
  final EditorIndentationOptions Function() indentationOptions;
  final bool Function() isMounted;
  final void Function(String message) onError;
  final void Function() onFormatted;
  final String? workspacePath;
  final String filePath;
  final ScmQuickDiffAdapter scmQuickDiffAdapter;
  final FormattingExecutionPipeline executionPipeline;
  final StableEditorScrollState? Function()? captureViewport;
  final void Function(StableEditorScrollState state)? restoreViewport;
  final Future<Object?> Function(List<Object>, FormattingKind)? selectFormatter;
  final ValueChanged<bool>? onFormatterConflict;

  final List<TextEditingValue> _formatUndoValues = [];
  final List<StableEditorScrollState?> _formatUndoViewports = [];
  final Set<FormattingCancellationSource> _activeCancellationSources = {};
  bool _isApplyingFormatting = false;
  final DefaultFormatterService _defaultFormatterService =
      const DefaultFormatterService();
  final FormattingProviderRegistry registry = FormattingProviderRegistry();
  final List<FormattingDisposable> _lspRegistrations = [];

  EditorFormattingController({
    required this.editorController,
    required this.service,
    required this.preferences,
    required this.languageId,
    required this.indentationOptions,
    required this.isMounted,
    required this.onError,
    required this.onFormatted,
    required this.workspacePath,
    required this.filePath,
    ScmQuickDiffAdapter? scmQuickDiffAdapter,
    FormattingExecutionPipeline? executionPipeline,
    this.captureViewport,
    this.restoreViewport,
    this.selectFormatter,
    this.onFormatterConflict,
  }) : scmQuickDiffAdapter = scmQuickDiffAdapter ?? ScmQuickDiffAdapter(),
       executionPipeline =
           executionPipeline ?? const FormattingExecutionPipeline();

  bool get isApplyingFormatting => _isApplyingFormatting;

  bool get supportsDocumentFormatting {
    final formatter = service;
    return formatter is! LspEditorFormattingService ||
        formatter.canFormatDocument;
  }

  bool get supportsRangeFormatting {
    final formatter = service;
    return formatter is! LspEditorFormattingService || formatter.canFormatRange;
  }

  List<Object> availableFormatters(FormattingKind kind) {
    _refreshLspRegistrations();
    return switch (kind) {
      FormattingKind.file => registry.documentProvidersFor(_formattingDocument),
      FormattingKind.selection => registry.rangeProvidersFor(
        _formattingDocument,
      ),
    };
  }

  void recordUserEdit() {
    if (!_isApplyingFormatting) {
      for (final source in _activeCancellationSources) {
        source.cancel();
      }
      _formatUndoValues.clear();
      _formatUndoViewports.clear();
    }
  }

  bool undoLastFormatting() {
    if (_formatUndoValues.isEmpty) return false;
    final previous = _formatUndoValues.removeLast();
    final viewport = _formatUndoViewports.removeLast();
    _isApplyingFormatting = true;
    try {
      editorController.value = previous;
    } finally {
      _isApplyingFormatting = false;
    }
    if (viewport != null) restoreViewport?.call(viewport);
    onFormatted();
    return true;
  }

  Future<void> formatDocument({
    bool selectionOnly = false,
    LspRange? requestedRange,
    FormattingMode mode = FormattingMode.explicit,
  }) async {
    final kind = selectionOnly || requestedRange != null
        ? FormattingKind.selection
        : FormattingKind.file;
    final selection = editorController.selection;
    final requestText = editorController.text;
    final range =
        requestedRange ??
        (selectionOnly && selection.isValid && !selection.isCollapsed
            ? LspRange(
                start: _positionAtOffset(
                  editorController.text,
                  selection.start,
                ),
                end: _positionAtOffset(editorController.text, selection.end),
              )
            : null);
    if (selectionOnly && range == null) {
      if (mode == FormattingMode.explicit) onError('Select a range to format');
      return;
    }
    _refreshLspRegistrations();
    final document = _formattingDocument;
    final candidates = kind == FormattingKind.file
        ? registry.documentProvidersFor(document)
        : registry.rangeProvidersFor(document);
    final resolution = _defaultFormatterService.resolve(
      providers: candidates,
      preferences: preferences(),
      languageId: languageId(),
      kind: kind,
      mode: mode,
    );
    var provider = resolution.provider;
    if (resolution.status ==
            FormatterResolutionStatus.formatterChoiceRequired &&
        mode == FormattingMode.explicit &&
        selectFormatter != null) {
      provider = await selectFormatter!(candidates, kind);
    }
    if (provider == null) {
      if (mode == FormattingMode.silent &&
          (resolution.status ==
                  FormatterResolutionStatus.defaultFormatterUnavailable ||
              resolution.status ==
                  FormatterResolutionStatus.formatterChoiceRequired)) {
        onFormatterConflict?.call(true);
      } else if (resolution.status == FormatterResolutionStatus.noProvider) {
        onFormatterConflict?.call(false);
      }
      if (mode == FormattingMode.explicit) {
        onError(_resolutionMessage(resolution.status));
      }
      return;
    }
    if (editorController.text != requestText ||
        editorController.selection != selection) {
      return;
    }
    onFormatterConflict?.call(false);
    final cancellationSource = _createCancellationSource();
    try {
      final viewport = captureViewport?.call();
      final edits = kind == FormattingKind.file
          ? await (provider as DocumentFormattingEditProvider)
                .provideDocumentFormattingEdits(
                  document,
                  _formattingOptions,
                  cancellationToken: cancellationSource,
                )
          : await (provider as DocumentRangeFormattingEditProvider)
                .provideDocumentRangeFormattingEdits(
                  document,
                  range!,
                  _formattingOptions,
                  cancellationToken: cancellationSource,
                );
      if (cancellationSource.isCancellationRequested ||
          editorController.text != requestText ||
          editorController.selection != selection) {
        return;
      }
      if (!isMounted()) return;
      await _applyEdits(edits, viewport: viewport);
    } on FormattingRequestOutdatedException {
      return;
    } catch (error, stackTrace) {
      if (mode == FormattingMode.explicit) {
        onError('Formatting failed: $error');
      } else {
        _reportAutomaticFormattingError(error, stackTrace);
      }
    } finally {
      _releaseCancellationSource(cancellationSource);
    }
  }

  String _resolutionMessage(FormatterResolutionStatus status) =>
      switch (status) {
        FormatterResolutionStatus.noProvider =>
          'No formatter is available for this document',
        FormatterResolutionStatus.defaultFormatterUnavailable =>
          'The configured default formatter is unavailable for this document',
        FormatterResolutionStatus.selectionRequiresRangeProvider =>
          'The configured formatter cannot format a selection',
        FormatterResolutionStatus.formatterDoesNotSupportKind =>
          'The configured formatter does not support this formatting action',
        FormatterResolutionStatus.formatterChoiceRequired =>
          'Choose a default formatter before formatting',
        FormatterResolutionStatus.selected => '',
      };

  Future<void> formatOnType(String character, int offset) async {
    final cancellationSource = _createCancellationSource();
    try {
      final requestText = editorController.text;
      final requestSelection = editorController.selection;
      _refreshLspRegistrations();
      final document = _formattingDocument;
      final providers = registry.onTypeProvidersFor(document);
      OnTypeFormattingEditProvider? provider;
      for (final candidate in providers) {
        if (candidate.triggerCharacters.contains(character)) {
          provider = candidate;
          break;
        }
      }
      if (provider == null) return;
      final edits = await provider.provideOnTypeFormattingEdits(
        document,
        _positionAtOffset(requestText, offset),
        character,
        _formattingOptions,
        cancellationToken: cancellationSource,
      );
      if (cancellationSource.isCancellationRequested ||
          !isMounted() ||
          !preferences().formatOnType ||
          editorController.text != requestText ||
          editorController.selection != requestSelection) {
        return;
      }
      await _applyEdits(edits);
    } on FormattingRequestOutdatedException {
      return;
    } catch (error, stackTrace) {
      if (preferences().formatOnType) {
        _reportAutomaticFormattingError(error, stackTrace);
      }
    } finally {
      _releaseCancellationSource(cancellationSource);
    }
  }

  Future<void> formatModifiedLines({
    FormattingMode mode = FormattingMode.explicit,
  }) async {
    final root = workspacePath;
    if (root == null) {
      if (mode == FormattingMode.explicit) {
        onError('Format Modified Lines requires an open Git workspace');
      }
      return;
    }
    final cancellationSource = _createCancellationSource();
    try {
      final requestText = editorController.text;
      final requestSelection = editorController.selection;
      final ranges = await scmQuickDiffAdapter.modifiedRanges(
        workspacePath: root,
        filePath: filePath,
        documentText: requestText,
      );
      if (cancellationSource.isCancellationRequested ||
          !isMounted() ||
          editorController.text != requestText ||
          editorController.selection != requestSelection) {
        return;
      }
      if (ranges == null) {
        if (mode == FormattingMode.explicit) {
          onError('Format Modified Lines requires a Git repository with HEAD');
        }
        return;
      }
      if (ranges.isEmpty) return;
      final mergedRanges = RangeOverlapMerger.merge(ranges);
      final viewport = captureViewport?.call();
      final edits = await _formatRanges(
        mergedRanges,
        mode,
        cancellationToken: cancellationSource,
      );
      if (cancellationSource.isCancellationRequested || !isMounted()) return;
      await _applyEdits(edits, viewport: viewport);
    } on FormattingRequestOutdatedException {
      return;
    } catch (error, stackTrace) {
      if (mode == FormattingMode.explicit) {
        onError('Formatting modified lines failed: $error');
      } else {
        _reportAutomaticFormattingError(error, stackTrace);
      }
    } finally {
      _releaseCancellationSource(cancellationSource);
    }
  }

  Future<void> formatOnSave() async {
    final effective = preferences();
    if (!effective.formatOnSave) return;
    switch (effective.formatOnSaveMode) {
      case FormatOnSaveMode.file:
        await formatDocument(mode: FormattingMode.silent);
      case FormatOnSaveMode.modifications:
        await formatModifiedLines(mode: FormattingMode.silent);
      case FormatOnSaveMode.modificationsIfAvailable:
        final root = workspacePath;
        if (root == null) {
          await formatDocument(mode: FormattingMode.silent);
          return;
        }
        final cancellationSource = _createCancellationSource();
        try {
          final requestText = editorController.text;
          final requestSelection = editorController.selection;
          final ranges = await scmQuickDiffAdapter.modifiedRanges(
            workspacePath: root,
            filePath: filePath,
            documentText: requestText,
          );
          if (cancellationSource.isCancellationRequested ||
              !isMounted() ||
              editorController.text != requestText ||
              editorController.selection != requestSelection) {
            return;
          }
          if (ranges == null) {
            await formatDocument(mode: FormattingMode.silent);
          } else if (ranges.isNotEmpty) {
            final edits = await _formatRanges(
              RangeOverlapMerger.merge(ranges),
              FormattingMode.silent,
              cancellationToken: cancellationSource,
            );
            if (!cancellationSource.isCancellationRequested) {
              await _applyEdits(edits, viewport: captureViewport?.call());
            }
          }
        } on FormattingRequestOutdatedException {
          return;
        } catch (error, stackTrace) {
          _reportAutomaticFormattingError(error, stackTrace);
        } finally {
          _releaseCancellationSource(cancellationSource);
        }
    }
  }

  void _reportAutomaticFormattingError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'editor formatting',
        context: ErrorDescription('while applying automatic formatting'),
      ),
    );
  }

  Future<List<TextEdit>> _formatRanges(
    List<LspRange> ranges,
    FormattingMode mode, {
    required FormattingCancellationToken cancellationToken,
  }) async {
    _refreshLspRegistrations();
    final document = _formattingDocument;
    final providers = registry.rangeProvidersFor(document);
    final resolution = _defaultFormatterService.resolve(
      providers: providers,
      preferences: preferences(),
      languageId: languageId(),
      kind: FormattingKind.selection,
      mode: mode,
    );
    var provider = resolution.provider;
    if (resolution.status ==
            FormatterResolutionStatus.formatterChoiceRequired &&
        mode == FormattingMode.explicit &&
        selectFormatter != null) {
      provider = await selectFormatter!(providers, FormattingKind.selection);
    }
    if (provider == null) {
      if (mode == FormattingMode.silent &&
          (resolution.status ==
                  FormatterResolutionStatus.defaultFormatterUnavailable ||
              resolution.status ==
                  FormatterResolutionStatus.formatterChoiceRequired)) {
        onFormatterConflict?.call(true);
      } else if (resolution.status == FormatterResolutionStatus.noProvider) {
        onFormatterConflict?.call(false);
      }
      if (mode == FormattingMode.explicit) {
        onError(_resolutionMessage(resolution.status));
      }
      return const [];
    }
    onFormatterConflict?.call(false);

    final rangeProvider = provider as DocumentRangeFormattingEditProvider;
    final requestText = document.text;
    final requestSelection = editorController.selection;
    final edits = <TextEdit>[];
    for (final range in ranges) {
      if (cancellationToken.isCancellationRequested ||
          editorController.text != requestText ||
          editorController.selection != requestSelection) {
        throw FormattingRequestOutdatedException();
      }
      edits.addAll(
        await rangeProvider.provideDocumentRangeFormattingEdits(
          document,
          range,
          _formattingOptions,
          cancellationToken: cancellationToken,
        ),
      );
    }
    if (cancellationToken.isCancellationRequested ||
        editorController.text != requestText ||
        editorController.selection != requestSelection) {
      throw FormattingRequestOutdatedException();
    }
    return edits;
  }

  FormattingCancellationSource _createCancellationSource() {
    final source = FormattingCancellationSource();
    _activeCancellationSources.add(source);
    return source;
  }

  void _releaseCancellationSource(FormattingCancellationSource source) {
    _activeCancellationSources.remove(source);
  }

  FormattingDocument get _formattingDocument => FormattingDocument(
    uri: Uri.file(filePath).toString(),
    languageId: languageId(),
    text: editorController.text,
  );

  void _refreshLspRegistrations() {
    for (final registration in _lspRegistrations) {
      registration.dispose();
    }
    _lspRegistrations.clear();
    final formatter = service;
    if (formatter is! LspEditorFormattingService) {
      if (formatter is DocumentFormattingEditProvider) {
        _lspRegistrations.add(
          registry.registerDocumentProvider(
            formatter as DocumentFormattingEditProvider,
          ),
        );
      }
      if (formatter is DocumentRangeFormattingEditProvider) {
        _lspRegistrations.add(
          registry.registerRangeProvider(
            formatter as DocumentRangeFormattingEditProvider,
          ),
        );
      }
      if (formatter is OnTypeFormattingEditProvider) {
        _lspRegistrations.add(
          registry.registerOnTypeProvider(
            formatter as OnTypeFormattingEditProvider,
          ),
        );
      }
      return;
    }
    if (formatter.extension.canFormatDocument) {
      _lspRegistrations.add(registry.registerDocumentProvider(formatter));
    }
    if (formatter.extension.canFormatRange) {
      _lspRegistrations.add(registry.registerRangeProvider(formatter));
    }
    if (formatter.extension.canFormatOnType) {
      _lspRegistrations.add(registry.registerOnTypeProvider(formatter));
    }
  }

  void dispose() {
    for (final source in _activeCancellationSources) {
      source.cancel();
    }
    _activeCancellationSources.clear();
    for (final registration in _lspRegistrations) {
      registration.dispose();
    }
    _lspRegistrations.clear();
  }

  FormattingOptions get _formattingOptions {
    final indentation = indentationOptions();
    return FormattingOptions(
      tabSize: indentation.tabSize,
      insertSpaces: indentation.insertSpaces,
    );
  }

  Future<void> _applyEdits(
    List<TextEdit> edits, {
    StableEditorScrollState? viewport,
  }) async {
    if (edits.isNotEmpty) {
      final previous = editorController.value;
      final formatted = await executionPipeline.apply(previous, edits);
      if (!isMounted() ||
          editorController.text != previous.text ||
          editorController.selection != previous.selection) {
        return;
      }
      _formatUndoValues.add(previous);
      _formatUndoViewports.add(viewport);
      _isApplyingFormatting = true;
      try {
        editorController.value = formatted;
      } finally {
        _isApplyingFormatting = false;
      }
      if (viewport != null) restoreViewport?.call(viewport);
    }
    onFormatted();
  }

  LspPosition _positionAtOffset(String text, int offset) {
    final boundedOffset = offset.clamp(0, text.length).toInt();
    final prefix = text.substring(0, boundedOffset);
    final line = '\n'.allMatches(prefix).length;
    final lineStart = prefix.lastIndexOf('\n') + 1;
    return LspPosition(line: line, character: boundedOffset - lineStart);
  }
}

class LspEditorFormattingService
    implements
        EditorFormattingService,
        DocumentFormattingEditProvider,
        DocumentRangeFormattingEditProvider,
        OnTypeFormattingEditProvider {
  final EditorLspExtension extension;

  const LspEditorFormattingService(this.extension);

  @override
  String get id => 'lsp';

  bool get canFormatDocument =>
      extension.canFormatDocument || extension.canFormatRange;
  bool get canFormatRange => extension.canFormatRange;
  @override
  Set<String> get triggerCharacters => extension.formatOnTypeTriggers.toSet();

  @override
  Set<String> get languageIds => {extension.languageId};

  @override
  Future<List<TextEdit>> formatDocument(
    FormattingOptions options, {
    LspRange? range,
  }) {
    final formattingOptions = EditorIndentationOptions(
      tabSize: options.tabSize,
      insertSpaces: options.insertSpaces,
    );
    if (range == null &&
        !extension.canFormatDocument &&
        extension.canFormatRange) {
      return extension.formatDocument(
        options: formattingOptions,
        range: _wholeDocumentRange(extension.documentText),
      );
    }
    return extension.formatDocument(options: formattingOptions, range: range);
  }

  @override
  Future<List<TextEdit>> formatRanges(
    FormattingOptions options,
    List<LspRange> ranges,
  ) async {
    final edits = <TextEdit>[];
    for (final range in ranges) {
      edits.addAll(
        await extension.formatDocument(
          options: EditorIndentationOptions(
            tabSize: options.tabSize,
            insertSpaces: options.insertSpaces,
          ),
          range: range,
        ),
      );
    }
    return edits;
  }

  @override
  Future<List<TextEdit>> provideDocumentFormattingEdits(
    FormattingDocument document,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) {
    if (cancellationToken?.isCancellationRequested == true) {
      return Future.value(const []);
    }
    return formatDocument(options);
  }

  @override
  Future<List<TextEdit>> provideDocumentRangeFormattingEdits(
    FormattingDocument document,
    LspRange range,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) {
    if (cancellationToken?.isCancellationRequested == true) {
      return Future.value(const []);
    }
    return formatDocument(options, range: range);
  }

  @override
  Future<List<TextEdit>> provideOnTypeFormattingEdits(
    FormattingDocument document,
    LspPosition position,
    String character,
    FormattingOptions options, {
    FormattingCancellationToken? cancellationToken,
  }) {
    if (cancellationToken?.isCancellationRequested == true) {
      return Future.value(const []);
    }
    return formatOnType(options, position: position, character: character);
  }

  @override
  Future<List<TextEdit>> formatOnType(
    FormattingOptions options, {
    required LspPosition position,
    required String character,
  }) => extension.formatOnType(
    options: EditorIndentationOptions(
      tabSize: options.tabSize,
      insertSpaces: options.insertSpaces,
    ),
    position: position,
    character: character,
  );

  LspRange _wholeDocumentRange(String text) {
    final lines = text.split('\n');
    final lastLine = lines.last;
    return LspRange(
      start: const LspPosition(line: 0, character: 0),
      end: LspPosition(
        line: lines.length - 1,
        character: lastLine.endsWith('\r')
            ? lastLine.length - 1
            : lastLine.length,
      ),
    );
  }
}
