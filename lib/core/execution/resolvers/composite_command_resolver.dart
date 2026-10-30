import '../../languages/definitions/built_in_languages.dart';
import '../../languages/registry/language_registry.dart';
import 'command_resolver.dart';

/// Selects the first registered resolver that supports a file.
class CompositeCommandResolver implements ICommandResolver {
  final List<ICommandResolver> _resolvers;

  CompositeCommandResolver([Iterable<ICommandResolver> resolvers = const []])
    : _resolvers = List.of(resolvers);

  void registerResolver(ICommandResolver resolver) {
    _resolvers.insert(0, resolver);
  }

  @override
  bool canResolve(String filePath) => _resolvers.any(
    (resolver) => resolver.canResolve(filePath),
  );

  @override
  ExecutionPlan resolve(String filePath) {
    for (final resolver in _resolvers) {
      if (resolver.canResolve(filePath)) return resolver.resolve(filePath);
    }
    return ExecutionPlan(executable: 'cat', arguments: [filePath]);
  }
}

/// Resolves the built-in Dart, Python, shell, JavaScript, and fallback commands.
class BuiltInCommandResolver implements ICommandResolver {
  final LanguageRegistry _languageRegistry;

  BuiltInCommandResolver({LanguageRegistry? languageRegistry})
    : _languageRegistry =
          languageRegistry ?? createBuiltInLanguageRegistry();

  @override
  bool canResolve(String filePath) => true;

  @override
  ExecutionPlan resolve(String filePath) =>
      _languageRegistry.forPath(filePath)?.defaultExecutionResolver?.resolve(
        filePath,
      ) ??
      ExecutionPlan(executable: 'cat', arguments: [filePath]);
}
