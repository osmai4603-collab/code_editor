import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/core/lsp/connection/lsp_framing.dart';

void main() {
  group('LspFraming Unit Tests', () {
    late LspFraming framing;

    setUp(() {
      framing = LspFraming();
    });

    test('Encodes and decodes a simple JSON message', () {
      final jsonMsg = jsonEncode({'jsonrpc': '2.0', 'method': 'test', 'params': {}});
      final encoded = LspFraming.encode(jsonMsg);

      final decoded = framing.addBytes(encoded);
      expect(decoded.length, equals(1));
      expect(decoded.first, equals(jsonMsg));
      expect(framing.bufferLength, equals(0));
    });

    test('Decodes multibyte UTF-8 characters (Arabic and Emojis)', () {
      final jsonMsg = jsonEncode({
        'jsonrpc': '2.0',
        'result': {
          'text': 'مرحباً بالعالم! 🚀 كود محرر فلاتر',
          'symbols': ['∑', 'π', '≈', '🌟'],
        }
      });
      final encoded = LspFraming.encode(jsonMsg);
      final decoded = framing.addBytes(encoded);

      expect(decoded.length, equals(1));
      final parsed = jsonDecode(decoded.first) as Map<String, dynamic>;
      expect(parsed['result']['text'], equals('مرحباً بالعالم! 🚀 كود محرر فلاتر'));
    });

    test('Handles batching (multiple messages in a single byte chunk)', () {
      final msg1 = jsonEncode({'id': 1, 'method': 'm1'});
      final msg2 = jsonEncode({'id': 2, 'method': 'm2'});
      final msg3 = jsonEncode({'id': 3, 'method': 'm3'});

      final combinedBytes = BytesBuilder()
        ..add(LspFraming.encode(msg1))
        ..add(LspFraming.encode(msg2))
        ..add(LspFraming.encode(msg3));

      final decoded = framing.addBytes(combinedBytes.takeBytes());
      expect(decoded.length, equals(3));
      expect(decoded[0], equals(msg1));
      expect(decoded[1], equals(msg2));
      expect(decoded[2], equals(msg3));
    });

    test('Handles extreme fragmentation (1 byte at a time)', () {
      final msg = jsonEncode({'jsonrpc': '2.0', 'method': 'textDocument/completion', 'params': {'id': 99}});
      final encoded = LspFraming.encode(msg);

      final collected = <String>[];
      for (int i = 0; i < encoded.length; i++) {
        final res = framing.addBytes([encoded[i]]);
        collected.addAll(res);
      }

      expect(collected.length, equals(1));
      expect(collected.first, equals(msg));
      expect(framing.bufferLength, equals(0));
    });

    test('Handles stress test: 2,000 randomized chunks with various fragmentations', () {
      final random = Random(42);
      final originalMessages = <String>[];
      final fullBytes = BytesBuilder();

      for (int i = 0; i < 2000; i++) {
        final msg = jsonEncode({
          'id': i,
          'type': 'request_$i',
          'payload': 'حزمة اختبار رقم $i مع رمز 🎯'
        });
        originalMessages.add(msg);
        fullBytes.add(LspFraming.encode(msg));
      }

      final allBytes = fullBytes.takeBytes();
      final decodedMessages = <String>[];

      int offset = 0;
      while (offset < allBytes.length) {
        // Random chunk size between 1 and 256 bytes
        final chunkSize = min(random.nextInt(256) + 1, allBytes.length - offset);
        final chunk = allBytes.sublist(offset, offset + chunkSize);
        decodedMessages.addAll(framing.addBytes(chunk));
        offset += chunkSize;
      }

      expect(decodedMessages.length, equals(2000));
      for (int i = 0; i < 2000; i++) {
        expect(decodedMessages[i], equals(originalMessages[i]));
      }
      expect(framing.bufferLength, equals(0));
    });
  });
}
