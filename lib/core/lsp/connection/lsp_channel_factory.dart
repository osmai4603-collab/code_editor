import 'lsp_channel.dart';
import 'lsp_process_channel.dart';
import '../registry/language_server_descriptor.dart';

/// Creates the transport channel for a language server descriptor.
abstract interface class ILspChannelFactory {
  Future<LspChannel> createChannel(LanguageServerDescriptor descriptor);
}

/// Starts a language server as a process using stdio.
class ProcessLspChannelFactory implements ILspChannelFactory {
  @override
  Future<LspChannel> createChannel(
    LanguageServerDescriptor descriptor,
  ) => LspProcessChannel.start(
    executable: descriptor.command,
    args: descriptor.args,
    environment: descriptor.environment,
  );
}
