import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

GenerationRequest<String> _request() {
  return GenerationRequest<String>(
    prompt: 'What is the weather?',
    decode: (raw) => raw! as String,
    privacyPolicy: PrivacyPolicy.cloudAllowed,
    tools: const [
      ToolDefinition(name: 'weather', description: 'Current weather.'),
    ],
  );
}

const _call = ToolCall(id: 'c1', name: 'weather', arguments: {'city': 'Pune'});

void main() {
  group('SeiseiClient.runTools', () {
    test('should run tools and send their results back', () async {
      final provider = ScriptedProvider(
        id: 'scripted',
        replies: const [
          ScriptedReply.toolCalls([_call]),
          ScriptedReply.value('It is sunny in Pune.'),
        ],
      );
      final client = SeiseiClient(provider: provider);

      final response = await client.runTools(
        _request(),
        handlers: {
          'weather': (call) => {'city': call.arguments['city'], 'sky': 'sun'},
        },
      );

      expect(response.value, 'It is sunny in Pune.');
      expect(provider.requests, hasLength(2));
      final second = provider.requests.last.messages;
      expect(second.map((message) => message.role), [
        GenerationRole.user,
        GenerationRole.assistant,
        GenerationRole.tool,
      ]);
      expect(second[1].toolCalls, [_call]);
      expect(
        second[2].toolResult,
        const ToolResult(
          callId: 'c1',
          name: 'weather',
          content: {'city': 'Pune', 'sky': 'sun'},
        ),
      );
    });

    test('should throw toolRejected when approval is refused', () async {
      final client = SeiseiClient(
        provider: ScriptedProvider(
          id: 'scripted',
          replies: const [
            ScriptedReply.toolCalls([_call]),
          ],
        ),
      );

      await expectLater(
        client.runTools(
          _request(),
          handlers: {'weather': (call) => 'sun'},
          approve: (call) => false,
        ),
        throwsA(
          isA<ToolRejectedException>()
              .having(
                (error) => error.code,
                'code',
                SeiseiErrorCode.toolRejected,
              )
              .having((error) => error.call, 'call', _call),
        ),
      );
    });

    test('should answer an unknown tool with an error result', () async {
      final provider = ScriptedProvider(
        id: 'scripted',
        replies: const [
          ScriptedReply.toolCalls([ToolCall(id: 'x', name: 'missing')]),
          ScriptedReply.value('Sorry.'),
        ],
      );

      await SeiseiClient(
        provider: provider,
      ).runTools(_request(), handlers: const {});

      final result = provider.requests.last.messages.last.toolResult!;
      expect(result.isError, isTrue);
      expect(result.callId, 'x');
    });

    test('should stop at the step limit', () async {
      final client = SeiseiClient(
        provider: ScriptedProvider(
          id: 'scripted',
          replies: const [
            ScriptedReply.toolCalls([_call]),
            ScriptedReply.toolCalls([_call]),
          ],
        ),
      );

      await expectLater(
        client.runTools(
          _request(),
          handlers: {'weather': (call) => 'sun'},
          maxSteps: 2,
        ),
        throwsA(
          isA<SeiseiException>().having(
            (error) => error.code,
            'code',
            SeiseiErrorCode.toolStepLimitExceeded,
          ),
        ),
      );
    });

    test('should need multi-turn support after the first step', () async {
      final client = SeiseiClient(
        provider: ScriptedProvider(
          id: 'single-turn',
          capabilities: {
            ModelCapability.structuredGeneration,
            ModelCapability.toolCalling,
          },
          replies: const [
            ScriptedReply.toolCalls([_call]),
          ],
        ),
      );

      await expectLater(
        client.runTools(_request(), handlers: {'weather': (call) => 'sun'}),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });
}
