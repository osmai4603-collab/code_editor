import 'dart:io';

import '../../editor/indentation/language_indentation_rules.dart';
import '../../execution/resolvers/command_resolver.dart';
import '../../lsp/registry/language_server_descriptor.dart';
import '../models/language_definition.dart';
import '../registry/language_registry.dart';

/// Creates the built-in language registry used by core services.
LanguageRegistry createBuiltInLanguageRegistry() =>
    LanguageRegistry(builtInLanguageDefinitions());

LanguageDefinition? builtInLanguageDefinitionForId(String languageId) =>
    _builtInRegistry.byId(languageId);

final _builtInRegistry = createBuiltInLanguageRegistry();

/// Returns the language metadata shipped with the editor.
List<LanguageDefinition> builtInLanguageDefinitions() {
  const compiledGdscriptLsp =
      '/home/osm/flutter_projects/gdscript_lsp/build/gdscript_lsp';
  const sourceGdscriptLsp =
      '/home/osm/flutter_projects/gdscript_lsp/bin/gdscript_lsp.dart';
  final gdscriptCommand = File(compiledGdscriptLsp).existsSync()
      ? compiledGdscriptLsp
      : File(sourceGdscriptLsp).existsSync()
      ? _findDartExecutable()
      : null;

  return [
    LanguageDefinition(
      id: 'dart',
      name: 'Dart',
      extensions: const ['.dart'],
      lspDescriptor: LanguageServerDescriptor(
        id: 'dart',
        name: 'Dart Language Server',
        languageId: 'dart',
        fileExtensions: const ['.dart'],
        command: _findDartExecutable(),
        args: const ['language-server', '--protocol=lsp'],
      ),
      defaultExecutionResolver: FileCommandResolver(
        extensions: const ['.dart'],
        executable: _findDartExecutable(),
        leadingArguments: const ['run'],
      ),
      indentationRules: const BracketIndentationRules(),
    ),
    LanguageDefinition(
      id: 'python',
      name: 'Python',
      extensions: const ['.py'],
      lspDescriptor: const LanguageServerDescriptor(
        id: 'python',
        name: 'Python Pyright',
        languageId: 'python',
        fileExtensions: ['.py'],
        command: 'pyright-langserver',
        args: ['--stdio'],
      ),
      defaultExecutionResolver: FileCommandResolver(
        extensions: const ['.py'],
        executable: 'python3',
      ),
      indentationRules: const PythonIndentationRules(),
    ),
    LanguageDefinition(
      id: 'javascript',
      name: 'JavaScript',
      extensions: const ['.js', '.mjs', '.cjs'],
      defaultExecutionResolver: FileCommandResolver(
        extensions: const ['.js', '.mjs', '.cjs'],
        executable: 'node',
      ),
    ),
    LanguageDefinition(
      id: 'typescript',
      name: 'TypeScript',
      extensions: const ['.ts', '.tsx'],
    ),
    LanguageDefinition(id: 'json', name: 'JSON', extensions: const ['.json']),
    LanguageDefinition(
      id: 'yaml',
      name: 'YAML',
      extensions: const ['.yaml', '.yml'],
      filenames: const ['pubspec.yaml'],
    ),
    LanguageDefinition(
      id: 'html',
      name: 'HTML',
      extensions: const ['.html', '.htm'],
    ),
    LanguageDefinition(id: 'css', name: 'CSS', extensions: const ['.css']),
    LanguageDefinition(
      id: 'markdown',
      name: 'Markdown',
      extensions: const ['.md'],
    ),
    LanguageDefinition(
      id: 'shellscript',
      name: 'Shell Script',
      extensions: const ['.sh'],
      defaultExecutionResolver: FileCommandResolver(
        extensions: const ['.sh'],
        executable: 'bash',
      ),
    ),
    LanguageDefinition(id: 'xml', name: 'XML', extensions: const ['.xml']),
    LanguageDefinition(id: 'sql', name: 'SQL', extensions: const ['.sql']),
    LanguageDefinition(
      id: 'gdscript',
      name: 'GDScript',
      extensions: const ['.gd'],
      lspDescriptor: gdscriptCommand == null
          ? null
          : LanguageServerDescriptor(
              id: 'gdscript',
              name: 'GDScript Language Server',
              languageId: 'gdscript',
              fileExtensions: const ['.gd'],
              command: gdscriptCommand,
              args: gdscriptCommand == compiledGdscriptLsp
                  ? const []
                  : const ['run', sourceGdscriptLsp],
            ),
    ),
    LanguageDefinition(
      id: 'cpp',
      name: 'C/C++',
      extensions: const ['.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hxx'],
      indentationRules: const BracketIndentationRules(),
    ),
  ];
}

String _findDartExecutable() {
  const knownPaths = [
    '/home/osm/.development/flutter/bin/dart',
    '/home/osm/.development/flutter/bin/cache/dart-sdk/bin/dart',
  ];
  for (final path in knownPaths) {
    if (File(path).existsSync()) return path;
  }
  return 'dart';
}
