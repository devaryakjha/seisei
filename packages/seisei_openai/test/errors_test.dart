@TestOn('vm')
library;

import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

import 'support/fake_openai_server.dart';

GenerationRequest<String> _request({
  Duration? timeout,
  CancellationToken? cancellation,
  String Function(Object? raw)? decode,
}) {
  return GenerationRequest<String>(
    prompt: 'Hi',
    decode: decode ?? (raw) => raw as String? ?? '',
    privacyPolicy: PrivacyPolicy.cloudAllowed,
    timeout: timeout,
    cancellation: cancellation,
  );
}

void main() {
  late FakeOpenAiServer server;
  late OpenAiCompatibleProvider provider;

  setUp(() async {
    server = await FakeOpenAiServer.start();
    provider = OpenAiCompatibleProvider(
      model: 'test-model',
      baseUrl: server.baseUrl,
    );
  });

  tearDown(() async {
    provider.close();
    await server.close();
  });

  group('HTTP status', () {
    for (final (status, code) in [
      (401, SeiseiErrorCode.unauthorized),
      (403, SeiseiErrorCode.unauthorized),
      (408, SeiseiErrorCode.timeout),
      (504, SeiseiErrorCode.timeout),
      (500, SeiseiErrorCode.providerUnavailable),
    ]) {
      test('should map $status to ${code.name}', () async {
        server.enqueue(JsonReply(const {}, statusCode: status));
        await expectLater(
          provider.generate(_request()),
          throwsSeiseiError(code),
        );
      });

      test('should map $status to ${code.name} when streaming', () async {
        server.enqueue(JsonReply(const {}, statusCode: status));
        await expectLater(
          provider.stream(_request()).drain<void>(),
          throwsSeiseiError(code),
        );
      });
    }

    test('should map 429 to a rate limit with Retry-After', () async {
      server.enqueue(
        const JsonReply(
          {
            'error': {'message': 'Slow down.'},
          },
          statusCode: 429,
          headers: {'retry-after': '7'},
        ),
      );

      await expectLater(
        provider.generate(_request()),
        throwsA(
          isA<RateLimitedException>()
              .having(
                (error) => error.code,
                'code',
                SeiseiErrorCode.rateLimited,
              )
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 7),
              ),
        ),
      );
    });

    test('should leave retryAfter empty for an unreadable header', () async {
      server.enqueue(
        const JsonReply({}, statusCode: 429, headers: {'retry-after': 'soon'}),
      );

      await expectLater(
        provider.generate(_request()),
        throwsA(
          isA<RateLimitedException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            isNull,
          ),
        ),
      );
    });
  });

  group('replies', () {
    test('should map a refusal to refused', () async {
      server.enqueue(
        JsonReply(completionBody(refusal: 'I cannot help with that.')),
      );
      await expectLater(
        provider.generate(_request()),
        throwsSeiseiError(SeiseiErrorCode.refused),
      );
    });

    test('should map an empty content filter reply to refused', () async {
      server.enqueue(JsonReply(completionBody(finishReason: 'content_filter')));
      await expectLater(
        provider.generate(_request()),
        throwsSeiseiError(SeiseiErrorCode.refused),
      );
    });

    test('should map a cut-off structured reply to truncated', () async {
      const schema = ObjectSchema(
        name: 'Note',
        fields: {'title': ObjectField.string()},
      );
      server.enqueue(
        JsonReply(
          completionBody(content: '{"title": "Ha', finishReason: 'length'),
        ),
      );

      await expectLater(
        provider.generate(
          GenerationRequest<Map<String, Object?>>.structured(
            prompt: 'Note',
            schema: schema,
            fromJson: (json) => json,
            privacyPolicy: PrivacyPolicy.cloudAllowed,
          ),
        ),
        throwsSeiseiError(SeiseiErrorCode.truncated),
      );
    });

    test('should wrap decoder errors in a decode exception', () async {
      server.enqueue(JsonReply(completionBody(content: 'text')));
      await expectLater(
        provider.generate(
          _request(decode: (raw) => throw ArgumentError('bad value')),
        ),
        throwsA(isA<DecodeException>()),
      );
    });

    test('should report the finish reason and usage', () async {
      server.enqueue(JsonReply(completionBody(content: 'Hello')));

      final response = await provider.generate(_request());

      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.inputTokens, 3);
      expect(response.usage?.outputTokens, 5);
      expect(response.usage?.totalTokens, 8);
    });

    test('should report the finish reason on the final chunk', () async {
      server.enqueue(
        SseReply([
          chunkBody(content: 'Hel'),
          chunkBody(content: 'lo', finishReason: 'length'),
          '[DONE]',
        ]),
      );

      final chunks = await provider.stream(_request()).toList();

      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.finishReason, FinishReason.length);
    });
  });

  test('should not send a request that is already cancelled', () async {
    final token = CancellationToken()..cancel();
    await expectLater(
      provider.generate(_request(cancellation: token)),
      throwsSeiseiError(SeiseiErrorCode.cancelled),
    );
    expect(server.requests, isEmpty);
  });

  test('should map a dropped stream to provider unavailable', () async {
    server.enqueue(DroppedSseReply([chunkBody(content: 'Hel')]));

    await expectLater(
      provider.stream(_request()).drain<void>(),
      throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
    );
  });

  testProviderErrorConformance(
    'OpenAiCompatibleProvider',
    hangingProvider: () async {
      final server = await FakeOpenAiServer.start();
      for (var i = 0; i < 2; i++) {
        server.enqueue(const HangingReply());
      }
      final provider = OpenAiCompatibleProvider(
        model: 'test-model',
        baseUrl: server.baseUrl,
      );
      addTearDown(() async {
        provider.close();
        await server.close();
      });
      return provider;
    },
  );
}
