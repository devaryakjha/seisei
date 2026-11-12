import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:seisei/seisei.dart';
import 'package:seisei_apple/seisei_apple.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

GenerationRequest<String> _request({
  Duration? timeout,
  CancellationToken? cancellation,
  String Function(Object? raw)? decode,
}) {
  return GenerationRequest<String>(
    prompt: 'Hi',
    decode: decode ?? (raw) => raw as String? ?? '',
    timeout: timeout,
    cancellation: cancellation,
  );
}

AppleFoundationModelsProvider _provider(_ScriptedBackend backend) {
  return AppleFoundationModelsProvider(backend: backend);
}

void main() {
  group('native errors', () {
    for (final (error, code) in [
      (
        PlatformException(code: 'refused', message: 'guardrailViolation'),
        SeiseiErrorCode.refused,
      ),
      (
        PlatformException(code: 'rate_limited', message: 'rateLimited'),
        SeiseiErrorCode.rateLimited,
      ),
      (
        PlatformException(code: 'decode_failed', message: 'decodingFailure'),
        SeiseiErrorCode.decodeFailed,
      ),
      (
        PlatformException(code: 'cancelled', message: 'CancellationError()'),
        SeiseiErrorCode.cancelled,
      ),
      (
        PlatformException(
          code: 'generation_failed',
          message: 'assetsUnavailable',
        ),
        SeiseiErrorCode.providerUnavailable,
      ),
      (
        // Older plugins report every failure as generation_failed.
        PlatformException(
          code: 'generation_failed',
          message: 'GenerationError.guardrailViolation(...)',
        ),
        SeiseiErrorCode.refused,
      ),
      (
        const ProcessException('/usr/bin/fm', [], 'concurrentRequests', 1),
        SeiseiErrorCode.rateLimited,
      ),
      (StateError('boom'), SeiseiErrorCode.providerUnavailable),
    ]) {
      test('should map $error to ${code.name}', () async {
        final provider = _provider(_ScriptedBackend(error: error));
        await expectLater(
          provider.generate(_request()),
          throwsSeiseiError(code),
        );
      });

      test('should map $error to ${code.name} when streaming', () async {
        final provider = _provider(_ScriptedBackend(error: error));
        await expectLater(
          provider.stream(_request()).drain<void>(),
          throwsSeiseiError(code),
        );
      });
    }

    test('should map a failure after the first chunk', () async {
      final provider = _provider(
        _ScriptedBackend(
          streamValues: ['Hel'],
          error: PlatformException(code: 'generation_failed'),
        ),
      );
      final chunks = <GenerationChunk<String>>[];

      await expectLater(
        provider.stream(_request()).forEach(chunks.add),
        throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
      );
      expect(chunks.single.delta, 'Hel');
    });

    test('should wrap decoder errors in a decode exception', () async {
      final provider = _provider(_ScriptedBackend());
      await expectLater(
        provider.generate(
          _request(decode: (raw) => throw ArgumentError('bad value')),
        ),
        throwsA(isA<DecodeException>()),
      );
    });

    test('should report a stop finish reason', () async {
      final response = await _provider(_ScriptedBackend()).generate(_request());
      expect(response.finishReason, FinishReason.stop);
    });
  });

  group('timeouts and cancellation', () {
    test('should time out a hanging request and signal the backend', () async {
      final backend = _ScriptedBackend(hang: true);

      await expectLater(
        _provider(
          backend,
        ).generate(_request(timeout: const Duration(milliseconds: 20))),
        throwsSeiseiError(SeiseiErrorCode.timeout),
      );
      await backend.aborted.future;
    });

    test('should cancel a hanging stream and stop listening', () async {
      final backend = _ScriptedBackend(hang: true, streamValues: ['Hel']);
      final token = CancellationToken();
      final chunks = <GenerationChunk<String>>[];

      final done = _provider(
        backend,
      ).stream(_request(cancellation: token)).forEach(chunks.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();

      await expectLater(done, throwsSeiseiError(SeiseiErrorCode.cancelled));
      expect(chunks.single.delta, 'Hel');
      await backend.streamCancelled.future;
    });

    test('should not call the backend once cancelled', () async {
      final backend = _ScriptedBackend();
      final token = CancellationToken()..cancel();

      await expectLater(
        _provider(backend).generate(_request(cancellation: token)),
        throwsSeiseiError(SeiseiErrorCode.cancelled),
      );
      expect(backend.requests, isEmpty);
    });
  });

  testProviderErrorConformance(
    'AppleFoundationModelsProvider',
    hangingProvider: () => _provider(_ScriptedBackend(hang: true)),
  );

  test('method channel backend should cancel an aborted respond', () async {
    const channel = MethodChannel('test.seisei/cancel');
    final binding = flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
    final reply = Completer<Object?>();
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'cancel') {
        reply.complete('late');
        return null;
      }
      return reply.future;
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
    final abort = Completer<void>();

    final response =
        MethodChannelAppleFoundationModelsBackend(
          channel: channel,
        ).respond(
          AppleFoundationModelsRequest(
            prompt: 'Hi',
            mode: AppleFoundationModelsMode.system,
            abortTrigger: abort.future,
          ),
        );
    abort.complete();
    await response;

    expect(calls.map((call) => call.method), ['respond', 'cancel']);
    expect(calls.last.arguments, {'requestId': 0});
  });
}

final class _ScriptedBackend implements AppleFoundationModelsBackend {
  _ScriptedBackend({
    this.streamValues = const [],
    this.error,
    this.hang = false,
  });

  final List<Object?> streamValues;
  final Object? error;
  final bool hang;
  final List<AppleFoundationModelsRequest> requests = [];
  final Completer<void> aborted = Completer<void>();
  final Completer<void> streamCancelled = Completer<void>();

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    return const AppleFoundationModelsAvailability(systemAvailable: true);
  }

  void _watch(AppleFoundationModelsRequest request) {
    requests.add(request);
    unawaited(request.abortTrigger?.then((_) => aborted.complete()));
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    _watch(request);
    // The scripted error is a PlatformException, ProcessException or Error.
    // ignore: only_throw_errors, replays whatever the test scripted.
    if (error case final error?) throw error;
    if (hang) await Completer<void>().future;
    return 'ok';
  }

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) {
    _watch(request);
    late final StreamController<Object?> controller;
    controller = StreamController<Object?>(
      onListen: () {
        streamValues.forEach(controller.add);
        if (error case final error?) {
          controller.addError(error);
          unawaited(controller.close());
        } else if (!hang) {
          controller.add({'done': true, 'value': streamValues.join()});
          unawaited(controller.close());
        }
      },
      onCancel: () {
        if (!streamCancelled.isCompleted) streamCancelled.complete();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> closeSession(String sessionId) async {}
}
