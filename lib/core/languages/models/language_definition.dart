import '../../editor/indentation/language_indentation_rules.dart';
import '../../execution/resolvers/command_resolver.dart';
import '../../lsp/registry/language_server_descriptor.dart';

/// Optional capabilities and file matching rules for a supported language.
class LanguageDefinition {
  final String id;
  final String name;
  final List<String> extensions;
  final List<String> filenames;
  final LanguageServerDescriptor? lspDescriptor;
  final ICommandResolver? defaultExecutionResolver;
  final LanguageIndentationRules? indentationRules;

  LanguageDefinition({
    required this.id,
    required this.name,
    required List<String> extensions,
    List<String> filenames = const [],
    this.lspDescriptor,
    this.defaultExecutionResolver,
    this.indentationRules,
  }) : extensions = List.unmodifiable(extensions),
       filenames = List.unmodifiable(filenames);

  bool matchesPath(String path) {
    final name = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    return filenames.any((filename) => filename.toLowerCase() == name) ||
        extensions.any((extension) => name.endsWith(extension.toLowerCase()));
  }
}
