@TestOn('vm')
library;

import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

import 'support/fake_openai_server.dart';

GenerationRequest<String> _request({Duration? timeout}) {
  return GenerationRequest<String>(
    prompt: 'Hi',
    decode: (raw) => raw as String? ?? '',
    privacyPolicy: PrivacyPolicy.cloudAllowed,
    timeout: timeout,
  );
}

const _fastRetry = OpenAiRetryPolicy(initialDelay: Duration.zero);

void main() {
  late FakeOpenAiServer server;

  setUp(() async {
    server = await FakeOpenAiServer.start();
  });

  tearDown(() => server.close());

  OpenAiCompatibleProvider provider({
    OpenAiRetryPolicy? retry,
    Future<Map<String, String>> Function()? headersProvider,
    bool streamUsage = true,
  }) {
    final result = OpenAiCompatibleProvider(
      model: 'test-model',
      baseUrl: server.baseUrl,
      apiKey: 'static-key',
      retry: retry,
      headersProvider: headersProvider,
      streamUsage: streamUsage,
    );
    addTearDown(result.close);
    return result;
  }

  group('OpenAiRetryPolicy', () {
    test('should back off exponentially up to the maximum', () {
      const policy = OpenAiRetryPolicy(
        maxAttempts: 5,
        initialDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 3),
      );

      expect(policy.delayAfter(1), const Duration(seconds: 1));
      expect(policy.delayAfter(2), const Duration(seconds: 2));
      expect(policy.delayAfter(3), const Duration(seconds: 3));
      expect(policy.delayAfter(5), isNull);
    });

    test('should use Retry-After and give up when it is too long', () {
      const policy = OpenAiRetryPolicy(maxDelay: Duration(seconds: 10));

      expect(
        policy.delayAfter(1, retryAfter: const Duration(seconds: 4)),
        const Duration(seconds: 4),
      );
      expect(
        policy.delayAfter(1, retryAfter: const Duration(minutes: 1)),
        isNull,
      );
    });
  });

  group('retries', () {
    test('should not retry without a policy', () async {
      server
        ..enqueue(const JsonReply({}, statusCode: 503))
        ..enqueue(JsonReply(completionBody(content: 'ok')));

      await expectLater(
        provider().generate(_request()),
        throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
      );
      expect(server.requests, hasLength(1));
    });

    for (final status in [429, 500, 502, 503, 504, 408]) {
      test('should retry HTTP $status', () async {
        server
          ..enqueue(JsonReply(const {}, statusCode: status))
          ..enqueue(JsonReply(completionBody(content: 'ok')));

        final response = await provider(retry: _fastRetry).generate(
          _request(),
        );

        expect(response.value, 'ok');
        expect(server.requests, hasLength(2));
      });
    }

    test('should not retry client errors', () async {
      server
        ..enqueue(const JsonReply({}, statusCode: 400))
        ..enqueue(JsonReply(completionBody(content: 'ok')));

      await expectLater(
        provider(retry: _fastRetry).generate(_request()),
        throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
      );
      expect(server.requests, hasLength(1));
    });

    test('should stop after the last attempt', () async {
      for (var i = 0; i < 3; i++) {
        server.enqueue(const JsonReply({}, statusCode: 503));
      }

      await expectLater(
        provider(retry: _fastRetry).generate(_request()),
        throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
      );
      expect(server.requests, hasLength(3));
    });

    test('should honour Retry-After on a rate limit', () async {
      server
        ..enqueue(
          const JsonReply({}, statusCode: 429, headers: {'retry-after': '0'}),
        )
        ..enqueue(JsonReply(completionBody(content: 'ok')));

      final response = await provider(
        retry: const OpenAiRetryPolicy(initialDelay: Duration(minutes: 1)),
      ).generate(_request());

      expect(response.value, 'ok');
    });

    test('should stop retrying when the request times out', () async {
      for (var i = 0; i < 3; i++) {
        server.enqueue(const JsonReply({}, statusCode: 503));
      }

      await expectLater(
        provider(
          retry: const OpenAiRetryPolicy(initialDelay: Duration(seconds: 5)),
        ).generate(_request(timeout: const Duration(milliseconds: 100))),
        throwsSeiseiError(SeiseiErrorCode.timeout),
      );
      expect(server.requests, hasLength(1));
    });

    test('should retry a stream before its first event', () async {
      server
        ..enqueue(const JsonReply({}, statusCode: 503))
        ..enqueue(
          SseReply([
            chunkBody(content: 'Hi', finishReason: 'stop'),
            '[DONE]',
          ]),
        );

      final chunks = await provider(
        retry: _fastRetry,
      ).stream(_request()).toList();

      expect(chunks.last.value, 'Hi');
      expect(server.requests, hasLength(2));
    });
  });

  group('headers provider', () {
    test('should send provided headers on every attempt', () async {
      var calls = 0;
      server
        ..enqueue(const JsonReply({}, statusCode: 503))
        ..enqueue(JsonReply(completionBody(content: 'ok')));

      await provider(
        retry: _fastRetry,
        headersProvider: () async {
          calls++;
          return {'authorization': 'Bearer token-$calls'};
        },
      ).generate(_request());

      expect(calls, 2);
      expect(
        server.requests.map((r) => r.headers.value('authorization')),
        ['Bearer token-1', 'Bearer token-2'],
      );
    });

    test('should fail as unauthorized when the provider throws', () async {
      await expectLater(
        provider(
          headersProvider: () async => throw StateError('signed out'),
        ).generate(_request()),
        throwsSeiseiError(SeiseiErrorCode.unauthorized),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('stream usage', () {
    test('should ask for usage and report it on the final chunk', () async {
      server.enqueue(
        SseReply([
          chunkBody(content: 'Hi', finishReason: 'stop'),
          {
            'id': 'chatcmpl-1',
            'object': 'chat.completion.chunk',
            'choices': <Object?>[],
            'usage': {
              'prompt_tokens': 4,
              'completion_tokens': 1,
              'total_tokens': 5,
            },
          },
          '[DONE]',
        ]),
      );

      final chunks = await provider().stream(_request()).toList();

      expect(server.requests.single.body['stream_options'], {
        'include_usage': true,
      });
      expect(chunks.last.usage?.inputTokens, 4);
      expect(chunks.last.usage?.outputTokens, 1);
    });

    test('should not send stream_options when turned off', () async {
      server.enqueue(
        SseReply([chunkBody(content: 'Hi', finishReason: 'stop'), '[DONE]']),
      );

      await provider(streamUsage: false).stream(_request()).drain<void>();

      expect(server.requests.single.body, isNot(contains('stream_options')));
    });
  });
}
