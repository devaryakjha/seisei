import 'dart:async';

import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

Matcher _code(SeiseiErrorCode code) {
  return isA<SeiseiException>().having((error) => error.code, 'code', code);
}

void main() {
  group('CancellationToken', () {
    test('should complete whenCancelled once', () async {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);

      token
        ..cancel()
        ..cancel();

      await token.whenCancelled;
      expect(token.isCancelled, isTrue);
    });
  });

  group('GenerationAbort', () {
    test('should have no trigger without a timeout or token', () async {
      final abort = GenerationAbort();

      expect(abort.trigger, isNull);
      expect(await abort.guard(Future.value(1)), 1);
      abort.close();
    });

    test('should abort with timeout after the timeout passes', () async {
      final abort = GenerationAbort(
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        abort.guard(Completer<void>().future),
        throwsA(_code(SeiseiErrorCode.timeout)),
      );
      expect(abort.isAborted, isTrue);
      expect(abort.throwIfAborted, throwsA(_code(SeiseiErrorCode.timeout)));
    });

    test('should abort with cancelled when the token is cancelled', () async {
      final token = CancellationToken();
      final abort = GenerationAbort(
        timeout: const Duration(seconds: 5),
        cancellation: token,
      );
      final guarded = abort.guard(Completer<void>().future);

      token.cancel();

      await expectLater(guarded, throwsA(_code(SeiseiErrorCode.cancelled)));
      abort.close();
    });

    test('should abort at once for a token that is already cancelled', () {
      final abort = GenerationAbort(
        cancellation: CancellationToken()..cancel(),
      );

      expect(abort.isAborted, isTrue);
      expect(abort.exception.code, SeiseiErrorCode.cancelled);
    });

    test('should not abort after close', () async {
      final abort = GenerationAbort(timeout: const Duration(milliseconds: 5))
        ..close();

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(abort.isAborted, isFalse);
    });

    test('should pass through a result that arrives first', () async {
      final abort = GenerationAbort(timeout: const Duration(seconds: 5));

      expect(await abort.guard(Future.value('done')), 'done');
      abort.close();
    });
  });

  test('should carry timeout and cancellation through copyWith', () {
    final token = CancellationToken();
    final request = GenerationRequest<String>(
      prompt: 'Hi',
      decode: (raw) => '$raw',
      timeout: const Duration(seconds: 3),
      cancellation: token,
    );

    final copy = request.copyWith(prompt: 'Again');

    expect(copy.timeout, const Duration(seconds: 3));
    expect(copy.cancellation, same(token));
  });
}
