import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'lsp_channel.dart';
import 'lsp_framing.dart';

/// تطبيق قناة LSP عبر عملية فرعية مستقلة (Process Stdio Channel)
class LspProcessChannel implements LspChannel {
  final Process _process;
  final LspFraming _framing = LspFraming();

  final StreamController<String> _incomingController = StreamController<String>.broadcast();
  final StreamController<String> _stderrController = StreamController<String>.broadcast();

  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  bool _isClosed = false;

  LspProcessChannel._(this._process) {
    // الاستماع لمخرجات الخادم القياسية وفك تأطيرها
    _stdoutSubscription = _process.stdout.listen(
      (chunk) {
        try {
          final messages = _framing.addBytes(chunk);
          for (final msg in messages) {
            if (!_incomingController.isClosed) {
              _incomingController.add(msg);
            }
          }
        } catch (e, st) {
          if (!_incomingController.isClosed) {
            _incomingController.addError(e, st);
          }
        }
      },
      onError: (error, st) {
        if (!_incomingController.isClosed) {
          _incomingController.addError(error, st);
        }
      },
      onDone: () {
        _cleanup();
      },
      cancelOnError: false,
    );

    // الاستماع لسجلات وأخطاء الخادم غير البروتوكولية
    _stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (!_stderrController.isClosed) {
          _stderrController.add(line);
        }
      },
      onError: (error) {
        // تجاهل أخطاء التدفق غير الحرجة لـ stderr
      },
      cancelOnError: false,
    );

    // عند خروج العملية
    _process.exitCode.then((_) {
      _cleanup();
    });
  }

  /// إطلاق خادم LSP في عملية منفصلة وتأسيس القناة
  static Future<LspProcessChannel> start({
    required String executable,
    required List<String> args,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );

    return LspProcessChannel._(process);
  }

  @override
  Stream<String> get incomingMessages => _incomingController.stream;

  @override
  Stream<String> get stderrMessages => _stderrController.stream;

  @override
  void sendMessage(String jsonMessage) {
    if (_isClosed) {
      throw StateError('Cannot send message on a closed LspProcessChannel');
    }
    final bytes = LspFraming.encode(jsonMessage);
    try {
      _process.stdin.add(bytes);
    } catch (_) {
      // التعامل مع انقطاع القناة أو إغلاق العملية أثناء الكتابة
    }
  }

  @override
  bool get isClosed => _isClosed;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    try {
      await _process.stdin.close();
    } catch (_) {}

    // إنهاء العملية بلطف ثم بقوة
    _process.kill(ProcessSignal.sigterm);
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        _process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    });

    _cleanup();
  }

  void _cleanup() {
    _isClosed = true;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    if (!_incomingController.isClosed) {
      _incomingController.close();
    }
    if (!_stderrController.isClosed) {
      _stderrController.close();
    }
  }
}
