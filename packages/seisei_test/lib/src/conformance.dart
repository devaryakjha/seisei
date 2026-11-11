import 'dart:async';

import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

/// Matches a [SeiseiException] with [code].
Matcher isSeiseiError(SeiseiErrorCode code) {
  return isA<SeiseiException>().having((error) => error.code, 'code', code);
}

/// Matches a future or callback that throws a [SeiseiException] with [code].
Matcher throwsSeiseiError(SeiseiErrorCode code) {
  return throwsA(isSeiseiError(code));
}

/// Registers the shared error tests every provider should pass.
///
/// [hangingProvider] must return a provider whose next `generate` or
/// `stream` call never completes on its own, for example one backed by a
/// server that does not reply. Each test builds a fresh provider. The tests
/// check that:
///
/// * a request that is already cancelled fails with
///   [SeiseiErrorCode.cancelled],
/// * a `timeout` ends a hanging call with [SeiseiErrorCode.timeout],
/// * cancelling ends a hanging call with [SeiseiErrorCode.cancelled],
/// * a router does not fall back to another provider after a cancellation.
///
/// Set [streams] to false for a provider without streaming support.
void testProviderErrorConformance(
  String description, {
  required FutureOr<SeiseiProvider> Function() hangingProvider,
  bool streams = true,
  Duration timeout = const Duration(milliseconds: 50),
}) {
  GenerationRequest<String> request({
    Duration? timeout,
    CancellationToken? cancellation,
  }) {
    return GenerationRequest<String>(
      prompt: 'conformance',
      decode: (raw) => '$raw',
      privacyPolicy: PrivacyPolicy.cloudAllowed,
      timeout: timeout,
      cancellation: cancellation,
    );
  }

  group('$description error conformance', () {
    test('should reject a request that is already cancelled', () async {
      final provider = await hangingProvider();
      final token = CancellationToken()..cancel();
      await expectLater(
        provider.generate(request(cancellation: token)),
        throwsSeiseiError(SeiseiErrorCode.cancelled),
      );
    });

    test('should time out a hanging generate call', () async {
      final provider = await hangingProvider();
      await expectLater(
        provider.generate(request(timeout: timeout)),
        throwsSeiseiError(SeiseiErrorCode.timeout),
      );
    });

    test('should cancel a hanging generate call', () async {
      final provider = await hangingProvider();
      final token = CancellationToken();
      final result = provider.generate(request(cancellation: token));
      await Future<void>.delayed(timeout);
      token.cancel();
      await expectLater(result, throwsSeiseiError(SeiseiErrorCode.cancelled));
    });

    test('should not fall back after a cancellation', () async {
      final provider = await hangingProvider();
      final fallback = await hangingProvider();
      final token = CancellationToken();
      final result = SeiseiRouter([
        provider,
        fallback,
      ]).generate(request(cancellation: token));
      await Future<void>.delayed(timeout);
      token.cancel();
      await expectLater(result, throwsSeiseiError(SeiseiErrorCode.cancelled));
    });

    if (streams) {
      test('should time out a hanging stream', () async {
        final provider = await hangingProvider();
        await expectLater(
          provider.stream(request(timeout: timeout)).drain<void>(),
          throwsSeiseiError(SeiseiErrorCode.timeout),
        );
      });

      test('should cancel a hanging stream', () async {
        final provider = await hangingProvider();
        final token = CancellationToken();
        final result = provider
            .stream(request(cancellation: token))
            .drain<void>();
        await Future<void>.delayed(timeout);
        token.cancel();
        await expectLater(
          result,
          throwsSeiseiError(SeiseiErrorCode.cancelled),
        );
      });
    }
  });
}
