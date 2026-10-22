@TestOn('vm')
library;

import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';
import 'package:test/test.dart';

import 'support/fake_openai_server.dart';

const _draftSchema = ObjectSchema(
  name: 'Draft',
  fields: {
    'title': ObjectField.string(),
    'tags': ObjectField.string(isArray: true, isRequired: false),
  },
);

GenerationRequest<String> _textRequest({
  PrivacyPolicy privacyPolicy = PrivacyPolicy.cloudAllowed,
  Map<String, Object?> metadata = const {},
  List<ToolDefinition> tools = const [],
}) {
  return GenerationRequest<String>(
    prompt: 'Say hi',
    decode: (raw) => raw as String? ?? '',
    privacyPolicy: privacyPolicy,
    metadata: metadata,
    tools: tools,
  );
}

GenerationRequest<Map<String, Object?>> _draftRequest() {
  return GenerationRequest<Map<String, Object?>>(
    prompt: 'Draft a post',
    decode: (raw) => Map<String, Object?>.from(raw! as Map),
    privacyPolicy: PrivacyPolicy.cloudAllowed,
    metadata: OpenAiCompatibleProvider.requestMetadata(
      responseSchema: _draftSchema,
    ),
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
      apiKey: 'sk-test',
    );
  });

  tearDown(() async {
    provider.close();
    await server.close();
  });

  group('availability', () {
    test('should report cloud capabilities and never on-device', () async {
      final custom = OpenAiCompatibleProvider(
        model: 'm',
        capabilities: {
          ModelCapability.structuredGeneration,
          ModelCapability.onDeviceInference,
        },
      );
      addTearDown(custom.close);

      final defaults = await provider.availability();
      final customAvailability = await custom.availability();

      expect(defaults.isAvailable, isTrue);
      expect(defaults.capabilities, {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
        ModelCapability.toolCalling,
      });
      expect(customAvailability.capabilities, {
        ModelCapability.structuredGeneration,
      });
    });

    test('should be unavailable without a model', () async {
      final unconfigured = OpenAiCompatibleProvider(model: ' ');
      addTearDown(unconfigured.close);

      final availability = await unconfigured.availability();

      expect(availability.isAvailable, isFalse);
      expect(availability.reason, contains('No model'));
    });

    test('should be unavailable with a relative base URL', () async {
      final relative = OpenAiCompatibleProvider(
        model: 'm',
        baseUrl: Uri.parse('v1'),
      );
      addTearDown(relative.close);

      expect((await relative.availability()).isAvailable, isFalse);
    });
  });

  group('privacy', () {
    for (final policy in [
      PrivacyPolicy.onDeviceOnly,
      PrivacyPolicy.onDevicePreferred,
    ]) {
      test('should reject $policy without sending a request', () async {
        await expectLater(
          provider.generate(_textRequest(privacyPolicy: policy)),
          throwsA(
            isA<PrivacyPolicyRejectedException>()
                .having((error) => error.policy, 'policy', policy)
                .having((error) => error.providerId, 'providerId', provider.id),
          ),
        );
        await expectLater(
          provider.stream(_textRequest(privacyPolicy: policy)).toList(),
          throwsA(isA<PrivacyPolicyRejectedException>()),
        );
        expect(server.requests, isEmpty);
      });
    }
  });

  group('generate', () {
    test('should send the chat completions request', () async {
      final custom = OpenAiCompatibleProvider(
        model: 'test-model',
        baseUrl: server.baseUrl,
        headers: {'api-key': 'azure-key'},
        queryParameters: {'api-version': '2024-10-21'},
      );
      addTearDown(custom.close);
      server.enqueue(JsonReply(completionBody(content: 'hi')));

      await custom.generate(
        _textRequest(
          metadata: OpenAiCompatibleProvider.requestMetadata(
            systemPrompt: 'Be brief.',
            requestOptions: {'temperature': 0, 'model': 'ignored'},
          ),
        ),
      );

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/chat/completions');
      expect(request.uri.queryParameters, {'api-version': '2024-10-21'});
      expect(request.headers.value('api-key'), 'azure-key');
      expect(request.headers.value('authorization'), isNull);
      expect(request.body, {
        'temperature': 0,
        'model': 'test-model',
        'messages': [
          {'role': 'system', 'content': 'Be brief.'},
          {'role': 'user', 'content': 'Say hi'},
        ],
        'stream': false,
      });
    });

    test('should send the API key as a bearer token', () async {
      server.enqueue(JsonReply(completionBody(content: 'hi')));

      await provider.generate(_textRequest());

      expect(
        server.requests.single.headers.value('authorization'),
        'Bearer sk-test',
      );
    });

    test('should decode reply text without a schema', () async {
      server.enqueue(JsonReply(completionBody(content: 'Hello!')));

      final response = await provider.generate(_textRequest());

      expect(response.value, 'Hello!');
      expect(response.providerId, 'openai_compatible');
      final completion = response.rawValue! as OpenAiCompletion;
      expect(completion.content, 'Hello!');
      expect(completion.model, 'test-model');
      expect(
        response.metadata[OpenAiCompatibleProvider.finishReasonMetadataKey],
        'stop',
      );
      expect(
        response.metadata[OpenAiCompatibleProvider.usageMetadataKey],
        containsPair('total_tokens', 8),
      );
    });

    test('should send a strict schema and validate the reply', () async {
      server.enqueue(
        JsonReply(completionBody(content: '{"title":"Hi","tags":null}')),
      );

      final response = await provider.generate(_draftRequest());

      expect(response.value, {'title': 'Hi', 'tags': null});
      final format =
          server.requests.single.body['response_format']!
              as Map<String, Object?>;
      expect(format['type'], 'json_schema');
      expect(format['json_schema'], containsPair('name', 'Draft'));
      expect(format['json_schema'], containsPair('strict', true));
    });

    test('should fail decoding when the reply breaks the schema', () async {
      server.enqueue(JsonReply(completionBody(content: '{"tags":[]}')));

      await expectLater(
        provider.generate(_draftRequest()),
        throwsA(
          isA<DecodeException>().having(
            (error) => error.message,
            'message',
            contains(r'$.title'),
          ),
        ),
      );
    });

    test('should fail decoding when the reply is not JSON', () async {
      server.enqueue(JsonReply(completionBody(content: 'Sure! Here it is')));

      await expectLater(
        provider.generate(_draftRequest()),
        throwsA(isA<DecodeException>()),
      );
    });

    test('should send tools and return requested tool calls', () async {
      server.enqueue(
        JsonReply(
          completionBody(
            finishReason: 'tool_calls',
            toolCalls: [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {
                  'name': 'lookup_weather',
                  'arguments': '{"city":"Pune"}',
                },
              },
            ],
          ),
        ),
      );

      final response = await provider.generate(
        _textRequest(
          tools: const [
            ToolDefinition(
              name: 'lookup_weather',
              description: 'Looks up the weather.',
              parameters: {
                'type': 'object',
                'properties': {
                  'city': {'type': 'string'},
                },
                'required': ['city'],
              },
            ),
            ToolDefinition(name: 'refresh', description: 'Refreshes.'),
          ],
        ),
      );

      expect(server.requests.single.body['tools'], [
        {
          'type': 'function',
          'function': {
            'name': 'lookup_weather',
            'description': 'Looks up the weather.',
            'parameters': {
              'type': 'object',
              'properties': {
                'city': {'type': 'string'},
              },
              'required': ['city'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'refresh',
            'description': 'Refreshes.',
            'parameters': {'type': 'object', 'properties': <String, Object?>{}},
          },
        },
      ]);
      expect(response.value, '');
      final calls =
          response.metadata[OpenAiCompatibleProvider.toolCallsMetadataKey]!
              as List<ToolCall>;
      expect(calls.single.id, 'call_1');
      expect(calls.single.name, 'lookup_weather');
      expect(calls.single.arguments, {'city': 'Pune'});
    });

    test('should reject tools when tool calling is not supported', () async {
      final noTools = OpenAiCompatibleProvider(
        model: 'm',
        baseUrl: server.baseUrl,
        capabilities: {ModelCapability.structuredGeneration},
      );
      addTearDown(noTools.close);

      await expectLater(
        noTools.generate(
          _textRequest(
            tools: const [ToolDefinition(name: 'a', description: 'b')],
          ),
        ),
        throwsA(
          isA<UnsupportedCapabilityException>().having(
            (error) => error.unsupportedCapabilities,
            'unsupported',
            {ModelCapability.toolCalling},
          ),
        ),
      );
      expect(server.requests, isEmpty);
    });

    test('should report HTTP errors as provider unavailable', () async {
      server.enqueue(
        const JsonReply({
          'error': {'message': 'Incorrect API key provided.'},
        }, statusCode: 401),
      );

      await expectLater(
        provider.generate(_textRequest()),
        throwsA(
          isA<SeiseiException>()
              .having(
                (error) => error.code,
                'code',
                SeiseiErrorCode.providerUnavailable,
              )
              .having(
                (error) => error.message,
                'message',
                allOf(contains('401'), contains('Incorrect API key')),
              ),
        ),
      );
    });

    test('should report unreachable servers as provider unavailable', () async {
      final baseUrl = server.baseUrl;
      await server.close();
      final offline = OpenAiCompatibleProvider(model: 'm', baseUrl: baseUrl);
      addTearDown(offline.close);

      await expectLater(
        offline.generate(_textRequest()),
        throwsA(
          isA<SeiseiException>().having(
            (error) => error.code,
            'code',
            SeiseiErrorCode.providerUnavailable,
          ),
        ),
      );
    });

    test('should let a router fall back past a failing endpoint', () async {
      server
        ..enqueue(const JsonReply({'error': 'overloaded'}, statusCode: 503))
        ..enqueue(JsonReply(completionBody(content: 'from backup')));
      final backup = OpenAiCompatibleProvider(
        model: 'backup',
        baseUrl: server.baseUrl,
        id: 'backup',
      );
      addTearDown(backup.close);

      final response = await SeiseiRouter([
        provider,
        backup,
      ]).generate(_textRequest());

      expect(response.providerId, 'backup');
      expect(response.value, 'from backup');
    });
  });

  group('stream', () {
    test('should stream text deltas and a terminal value', () async {
      server.enqueue(
        SseReply([
          chunkBody(content: 'Hel'),
          chunkBody(content: 'lo'),
          chunkBody(finishReason: 'stop'),
          '[DONE]',
        ]),
      );

      final chunks = await provider.stream(_textRequest()).toList();

      expect(server.requests.single.body['stream'], isTrue);
      expect(chunks.map((chunk) => chunk.delta), ['Hel', 'lo', null]);
      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.value, 'Hello');
      final completion = chunks.last.rawValue! as OpenAiCompletion;
      expect(completion.finishReason, 'stop');
      expect(chunks.first.structuredPatches, isEmpty);
    });

    test('should stream structured patches and partial values', () async {
      server.enqueue(
        SseReply([
          chunkBody(content: '{"title":"He'),
          chunkBody(content: 'llo","tags":["a"'),
          chunkBody(content: ']}'),
          '[DONE]',
        ]),
      );

      final chunks = await provider.stream(_draftRequest()).toList();

      expect(chunks[0].structuredPatches, [
        const StructuredPatch.add(path: ['title'], value: 'He'),
      ]);
      expect(chunks[0].partialValue, {'title': 'He'});
      expect(chunks[1].structuredPatches, [
        const StructuredPatch.replace(path: ['title'], value: 'Hello'),
        const StructuredPatch.add(path: ['tags'], value: ['a']),
      ]);
      expect(chunks[2].structuredPatches, isEmpty);
      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.value, {
        'title': 'Hello',
        'tags': ['a'],
      });
    });

    test('should assemble streamed tool calls', () async {
      server.enqueue(
        SseReply([
          chunkBody(
            toolCalls: [
              {
                'index': 0,
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'lookup_weather', 'arguments': ''},
              },
            ],
          ),
          chunkBody(
            toolCalls: [
              {
                'index': 0,
                'function': {'arguments': '{"city":'},
              },
            ],
          ),
          chunkBody(
            toolCalls: [
              {
                'index': 0,
                'function': {'arguments': '"Pune"}'},
              },
            ],
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]),
      );

      final chunks = await provider.stream(_textRequest()).toList();

      final completion = chunks.last.rawValue! as OpenAiCompletion;
      expect(completion.finishReason, 'tool_calls');
      expect(completion.content, isNull);
      expect(completion.toolCalls.single.name, 'lookup_weather');
      expect(completion.toolCalls.single.arguments, {'city': 'Pune'});
    });

    test('should finish when the stream ends without [DONE]', () async {
      server.enqueue(SseReply([chunkBody(content: 'ok')]));

      final chunks = await provider.stream(_textRequest()).toList();

      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.value, 'ok');
    });

    test('should surface error events', () async {
      server.enqueue(
        SseReply([
          chunkBody(content: 'par'),
          {
            'error': {'message': 'model crashed'},
          },
        ]),
      );

      await expectLater(
        provider.stream(_textRequest()).toList(),
        throwsA(
          isA<SeiseiException>().having(
            (error) => error.message,
            'message',
            contains('model crashed'),
          ),
        ),
      );
    });

    test('should report HTTP errors before streaming', () async {
      server.enqueue(const JsonReply({'error': 'nope'}, statusCode: 404));

      await expectLater(
        provider.stream(_textRequest()).toList(),
        throwsA(
          isA<SeiseiException>().having(
            (error) => error.message,
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('should require streaming support', () async {
      final noStreaming = OpenAiCompatibleProvider(
        model: 'm',
        baseUrl: server.baseUrl,
        capabilities: {ModelCapability.structuredGeneration},
      );
      addTearDown(noStreaming.close);

      await expectLater(
        noStreaming.stream(_textRequest()).toList(),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });
}
