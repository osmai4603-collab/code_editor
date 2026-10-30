import '../../languages/definitions/built_in_languages.dart';
import 'language_server_descriptor.dart';

/// Loads the server descriptors that a registry should expose.
abstract interface class ILspDescriptorSource {
  Future<List<LanguageServerDescriptor>> loadDescriptors();
}

/// Supplies the built-in language server descriptors.
class BuiltInLspDescriptorSource implements ILspDescriptorSource {
  List<LanguageServerDescriptor> get descriptors => List.unmodifiable(
    builtInLanguageDefinitions()
        .map((definition) => definition.lspDescriptor)
        .whereType<LanguageServerDescriptor>(),
  );

  @override
  Future<List<LanguageServerDescriptor>> loadDescriptors() async =>
      descriptors;
}
