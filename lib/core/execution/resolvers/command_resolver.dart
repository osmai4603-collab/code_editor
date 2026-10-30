/// An executable command and its arguments for a file.
class ExecutionPlan {
  final String executable;
  final List<String> arguments;

  ExecutionPlan({required this.executable, required List<String> arguments})
    : arguments = List.unmodifiable(arguments);
}

/// Resolves a file path into a command that can execute it.
abstract interface class ICommandResolver {
  bool canResolve(String filePath);

  ExecutionPlan resolve(String filePath);
}

/// Resolves file paths with a command and optional leading arguments.
class FileCommandResolver implements ICommandResolver {
  final List<String> _extensions;
  final String executable;
  final List<String> leadingArguments;

  FileCommandResolver({
    required Iterable<String> extensions,
    required this.executable,
    List<String> leadingArguments = const [],
  }) : _extensions = extensions.map((extension) => extension.toLowerCase()).toList(),
       leadingArguments = List.unmodifiable(leadingArguments);

  @override
  bool canResolve(String filePath) {
    final normalized = filePath.toLowerCase();
    return _extensions.any(normalized.endsWith);
  }

  @override
  ExecutionPlan resolve(String filePath) {
    if (!canResolve(filePath)) {
      throw ArgumentError.value(filePath, 'filePath', 'Unsupported file type');
    }
    return ExecutionPlan(
      executable: executable,
      arguments: [...leadingArguments, filePath],
    );
  }
}
